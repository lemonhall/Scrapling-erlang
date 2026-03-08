-module(scrapling_spider_e2e_tests).

-include_lib("eunit/include/eunit.hrl").

spider_resume_from_checkpoint_test() ->
    Checkpoint = scrapling_checkpoint:new(temp_crawldir()),
    Scheduler0 = scrapling_scheduler:new(),
    ResumeRequest = scrapling_request:new("https://example.com/detail", #{callback => parse_detail}),
    {true, Scheduler1} = scrapling_scheduler:enqueue(ResumeRequest, Scheduler0),
    ok = scrapling_checkpoint:save(Checkpoint, scrapling_scheduler:snapshot(Scheduler1)),

    Manager0 = scrapling_session_manager:new(),
    {ok, Manager1} = scrapling_session_manager:add(<<"default">>, scrapling_session_manager:custom(fun fetch_page/1), Manager0),
    try
        Result = scrapling_spider:start(
                   scrapling_test_spider_minimal,
                   #{session_manager => Manager1,
                     checkpoint_manager => Checkpoint,
                     resume => true}),
        ?assertEqual([#{kind => <<"detail">>, title => <<"Detail Page">>}], scrapling_crawl_result:items(Result)),
        ?assertEqual(1, scrapling_crawl_stats:requests_count(scrapling_crawl_result:stats(Result))),
        ?assertEqual(false, scrapling_checkpoint:has_checkpoint(Checkpoint))
    after
        ok = scrapling_checkpoint:cleanup(Checkpoint)
    end.

spider_pause_saves_checkpoint_test() ->
    Checkpoint = scrapling_checkpoint:new(temp_crawldir()),
    Manager0 = scrapling_session_manager:new(),
    {ok, Manager1} = scrapling_session_manager:add(<<"default">>, scrapling_session_manager:custom(fun fetch_full_page/1), Manager0),
    try
        Result = scrapling_spider:start(
                   scrapling_test_spider_minimal,
                   #{session_manager => Manager1,
                     checkpoint_manager => Checkpoint,
                     pause_after_requests => 1}),
        ?assertEqual(false, scrapling_crawl_result:completed(Result)),
        ?assertEqual([#{kind => <<"list">>, title => <<"List Page">>}], scrapling_crawl_result:items(Result)),
        ?assertEqual(1, scrapling_crawl_stats:requests_count(scrapling_crawl_result:stats(Result))),
        ?assertEqual(true, scrapling_checkpoint:has_checkpoint(Checkpoint)),
        {ok, Saved} = scrapling_checkpoint:load(Checkpoint),
        [Pending] = maps:get(requests, Saved),
        ?assertEqual(<<"https://example.com/detail">>, scrapling_request:url(Pending))
    after
        ok = scrapling_checkpoint:cleanup(Checkpoint)
    end.

spider_stream_yields_items_and_live_stats_test() ->
    TestPid = self(),
    GateRef = make_ref(),
    Manager0 = scrapling_session_manager:new(),
    Fetcher = fun(Request) -> fetch_stream_page(TestPid, GateRef, Request) end,
    {ok, Manager1} = scrapling_session_manager:add(<<"default">>, scrapling_session_manager:custom(Fetcher), Manager0),
    {ok, Stream} = scrapling_spider:stream(scrapling_test_spider_minimal, #{session_manager => Manager1}),

    {ok, FirstItem} = scrapling_spider:next(Stream, 2000),
    ?assertEqual(#{kind => <<"list">>, title => <<"List Page">>}, FirstItem),

    WorkerPid = receive
        {detail_fetch_started, StreamWorkerPid, GateRef0} when GateRef0 =:= GateRef ->
            StreamWorkerPid
    after 2000 ->
        erlang:error(stream_detail_gate_timeout)
    end,

    Stats1 = scrapling_spider:stats(Stream),
    ?assertEqual(1, scrapling_crawl_stats:requests_count(Stats1)),
    ?assertEqual(1, scrapling_crawl_stats:items_scraped(Stats1)),

    WorkerPid ! {allow_detail_fetch, GateRef},
    {ok, SecondItem} = scrapling_spider:next(Stream, 2000),
    ?assertEqual(#{kind => <<"detail">>, title => <<"Detail Page">>}, SecondItem),
    ?assertEqual(done, scrapling_spider:next(Stream, 2000)),

    Stats2 = scrapling_spider:stats(Stream),
    ?assertEqual(2, scrapling_crawl_stats:requests_count(Stats2)),
    ?assertEqual(2, scrapling_crawl_stats:items_scraped(Stats2)).

spider_blocked_request_retries_and_recovers_test() ->
    TestPid = self(),
    Manager0 = scrapling_session_manager:new(),
    Fetcher = fun(Request) -> fetch_blocked_retry_page(TestPid, recover, Request) end,
    {ok, Manager1} = scrapling_session_manager:add(<<"default">>, scrapling_session_manager:custom(Fetcher), Manager0),
    Result = scrapling_spider:start(scrapling_test_spider_blocked_retry, #{session_manager => Manager1}),
    Stats = scrapling_crawl_result:stats(Result),
    RetryDetails = receive
        {retry_request_seen, Details} -> Details
    after 2000 ->
        erlang:error(retry_request_not_seen)
    end,
    ?assertEqual([#{kind => <<"blocked-retry">>, title => <<"Recovered">>}], scrapling_crawl_result:items(Result)),
    ?assertEqual(true, scrapling_crawl_result:completed(Result)),
    ?assertEqual(2, scrapling_crawl_stats:requests_count(Stats)),
    ?assertEqual(1, maps:get(blocked_requests_count, Stats, 0)),
    ?assertEqual(1, scrapling_crawl_stats:items_scraped(Stats)),
    ?assertEqual(<<"https://example.com/recovered">>, maps:get(url, RetryDetails)),
    ?assertEqual(1, maps:get(retry_count, RetryDetails)),
    ?assertEqual(true, maps:get(dont_filter, RetryDetails)),
    ?assertEqual(4, maps:get(priority, RetryDetails)),
    ?assertEqual(undefined, maps:get(proxy, RetryDetails)),
    ?assertEqual(<<"url_shift">>, maps:get(retry_strategy, RetryDetails)).

spider_blocked_request_stops_after_max_retries_test() ->
    TestPid = self(),
    Manager0 = scrapling_session_manager:new(),
    Fetcher = fun(Request) -> fetch_blocked_retry_page(TestPid, exhaust, Request) end,
    {ok, Manager1} = scrapling_session_manager:add(<<"default">>, scrapling_session_manager:custom(Fetcher), Manager0),
    Result = scrapling_spider:start(scrapling_test_spider_blocked_retry, #{session_manager => Manager1}),
    Stats = scrapling_crawl_result:stats(Result),
    RetryDetails = receive
        {retry_request_seen, Details} -> Details
    after 2000 ->
        erlang:error(retry_request_not_seen)
    end,
    ?assertEqual([], scrapling_crawl_result:items(Result)),
    ?assertEqual(true, scrapling_crawl_result:completed(Result)),
    ?assertEqual(2, scrapling_crawl_stats:requests_count(Stats)),
    ?assertEqual(2, maps:get(blocked_requests_count, Stats, 0)),
    ?assertEqual(0, scrapling_crawl_stats:items_scraped(Stats)),
    ?assertEqual(1, maps:get(retry_count, RetryDetails)),
    ?assertEqual(true, maps:get(dont_filter, RetryDetails)),
    ?assertEqual(4, maps:get(priority, RetryDetails)).

fetch_page(Request) ->
    Url = scrapling_request:url(Request),
    case Url of
        <<"https://example.com/detail">> ->
            scrapling_response:new(200, <<"OK">>, [{"content-type", "text/html; charset=utf-8"}], <<"<html><body><h1>Detail Page</h1></body></html>">>, Url, get, [], #{});
        _ ->
            scrapling_response:new(200, <<"OK">>, [{"content-type", "text/html; charset=utf-8"}], <<"<html><body><h1>Unknown</h1></body></html>">>, Url, get, [], #{})
    end.

fetch_full_page(Request) ->
    Url = scrapling_request:url(Request),
    case Url of
        <<"https://example.com/list">> ->
            scrapling_response:new(200, <<"OK">>, [{"content-type", "text/html; charset=utf-8"}], <<"<html><body><h1>List Page</h1><a class='next' href='https://example.com/detail'>Next</a></body></html>">>, Url, get, [], #{});
        <<"https://example.com/detail">> ->
            scrapling_response:new(200, <<"OK">>, [{"content-type", "text/html; charset=utf-8"}], <<"<html><body><h1>Detail Page</h1></body></html>">>, Url, get, [], #{});
        _ ->
            scrapling_response:new(200, <<"OK">>, [{"content-type", "text/html; charset=utf-8"}], <<"<html><body><h1>Unknown</h1></body></html>">>, Url, get, [], #{})
    end.

fetch_stream_page(TestPid, GateRef, Request) ->
    Url = scrapling_request:url(Request),
    case Url of
        <<"https://example.com/list">> ->
            scrapling_response:new(200, <<"OK">>, [{"content-type", "text/html; charset=utf-8"}], <<"<html><body><h1>List Page</h1><a class='next' href='https://example.com/detail'>Next</a></body></html>">>, Url, get, [], #{});
        <<"https://example.com/detail">> ->
            TestPid ! {detail_fetch_started, self(), GateRef},
            receive
                {allow_detail_fetch, GateRef} -> ok
            after 2000 ->
                erlang:error(stream_detail_release_timeout)
            end,
            scrapling_response:new(200, <<"OK">>, [{"content-type", "text/html; charset=utf-8"}], <<"<html><body><h1>Detail Page</h1></body></html>">>, Url, get, [], #{});
        _ ->
            scrapling_response:new(200, <<"OK">>, [{"content-type", "text/html; charset=utf-8"}], <<"<html><body><h1>Unknown</h1></body></html>">>, Url, get, [], #{})
    end.

fetch_blocked_retry_page(TestPid, Mode, Request) ->
    Url = scrapling_request:url(Request),
    RetryCount = maps:get(retry_count, Request, 0),
    case {Url, RetryCount, Mode} of
        {<<"https://example.com/blocked">>, 0, _} ->
            blocked_response(Url);
        {<<"https://example.com/recovered">>, 1, recover} ->
            TestPid ! {retry_request_seen, retry_request_details(Request)},
            recovered_response(Url);
        {<<"https://example.com/recovered">>, 1, exhaust} ->
            TestPid ! {retry_request_seen, retry_request_details(Request)},
            blocked_response(Url);
        _ ->
            blocked_response(Url)
    end.

retry_request_details(Request) ->
    #{url => scrapling_request:url(Request),
      retry_count => maps:get(retry_count, Request, 0),
      dont_filter => scrapling_request:dont_filter(Request),
      priority => scrapling_request:priority(Request),
      proxy => maps:get(proxy, scrapling_request:session_opts(Request), undefined),
      retry_strategy => maps:get(retry_strategy, scrapling_request:meta(Request), undefined)}.

blocked_response(Url) ->
    scrapling_response:new(429, <<"Too Many Requests">>, [{"content-type", "text/html; charset=utf-8"}], <<"<html><body><h1>Blocked</h1></body></html>">>, Url, get, [], #{}).

recovered_response(Url) ->
    scrapling_response:new(200, <<"OK">>, [{"content-type", "text/html; charset=utf-8"}], <<"<html><body><h1>Recovered</h1></body></html>">>, Url, get, [], #{}).

temp_crawldir() ->
    filename:join(["_build", "test", "checkpoint", integer_to_list(erlang:unique_integer([positive, monotonic]))]).
