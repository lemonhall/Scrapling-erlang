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

temp_crawldir() ->
    filename:join(["_build", "test", "checkpoint", integer_to_list(erlang:unique_integer([positive, monotonic]))]).
