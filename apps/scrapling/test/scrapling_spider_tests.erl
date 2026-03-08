-module(scrapling_spider_tests).

-include_lib("eunit/include/eunit.hrl").

minimal_spider_crawl_test() ->
    Manager0 = scrapling_session_manager:new(),
    {ok, Manager1} = scrapling_session_manager:add(<<"default">>, scrapling_session_manager:custom(fun fetch_page/1), Manager0),
    Result = scrapling_spider:start(scrapling_test_spider_minimal, #{session_manager => Manager1}),
    Items = scrapling_crawl_result:items(Result),
    Stats = scrapling_crawl_result:stats(Result),
    ?assertEqual(true, scrapling_crawl_result:completed(Result)),
    ?assertEqual(2, length(Items)),
    ?assertEqual(2, scrapling_crawl_stats:requests_count(Stats)),
    ?assertEqual(2, scrapling_crawl_stats:items_scraped(Stats)),
    ?assertEqual([#{kind => <<"list">>, title => <<"List Page">>},
                   #{kind => <<"detail">>, title => <<"Detail Page">>}],
                 Items).

spider_allowed_domains_filter_test() ->
    Manager0 = scrapling_session_manager:new(),
    {ok, Manager1} = scrapling_session_manager:add(<<"default">>, scrapling_session_manager:custom(fun fetch_page/1), Manager0),
    Result = scrapling_spider:start(scrapling_test_spider_allowed_domain, #{session_manager => Manager1}),
    Items = scrapling_crawl_result:items(Result),
    Stats = scrapling_crawl_result:stats(Result),
    ?assertEqual([#{kind => <<"seed">>, title => <<"Unknown">>}], Items),
    ?assertEqual(1, scrapling_crawl_stats:requests_count(Stats)),
    ?assertEqual(1, scrapling_crawl_stats:items_scraped(Stats)).

fetch_page(Request) ->
    Url = scrapling_request:url(Request),
    case Url of
        <<"https://example.com/list">> ->
            html_response(Url, <<"<html><body><h1>List Page</h1><a class='next' href='https://example.com/detail'>Next</a></body></html>">>);
        <<"https://example.com/detail">> ->
            html_response(Url, <<"<html><body><h1>Detail Page</h1></body></html>">>);
        _ ->
            html_response(Url, <<"<html><body><h1>Unknown</h1></body></html>">>)
    end.

html_response(Url, Body) ->
    scrapling_response:new(200, <<"OK">>, [{"content-type", "text/html; charset=utf-8"}], Body, Url, get, [], #{}).
