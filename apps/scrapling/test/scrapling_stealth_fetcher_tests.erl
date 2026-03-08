-module(scrapling_stealth_fetcher_tests).

-include_lib("eunit/include/eunit.hrl").

stealth_fetch_response_test() ->
    {ok, Server, BaseUrl} = scrapling_test_httpd:start_link(fun html_handler/1),
    try
        Response = scrapling_stealth_fetcher:fetch(
                     BaseUrl ++ "/",
                     #{wait_selector => "h1", block_webrtc => true, allow_webgl => false}),
        ?assertEqual(200, scrapling_response:status_code(Response)),
        ?assertEqual(["Scrapling Erlang"], [scrapling_selector:get(Node) || Node <- scrapling_response:css("h1::text", Response)]),
        ?assertEqual(true, maps:get(stealth, scrapling_response:meta(Response)))
    after
        ok = scrapling_test_httpd:stop(Server)
    end.

stealth_fetch_page_action_click_test() ->
    {ok, Server, BaseUrl} = scrapling_test_httpd:start_link(fun html_handler/1),
    try
        Response = scrapling_stealth_fetcher:fetch(
                     BaseUrl ++ "/page-action",
                     #{page_action => [#{type => click, selector => ".load-more"}],
                       wait_selector => "#loaded-card",
                       wait_selector_state => "visible"}),
        ?assertMatch([{_, _}], binary:matches(scrapling_response:body(Response), <<"Loaded Via Action">>)),
        ?assertEqual(true, maps:get(stealth, scrapling_response:meta(Response)))
    after
        ok = scrapling_test_httpd:stop(Server)
    end.

html_handler(#{path := "/page-action"}) ->
    {ok, Body} = file:read_file(filename:join(["apps", "scrapling", "test", "fixtures", "browser_page_action.html"])),
    #{status => 200,
      headers => [{"content-type", "text/html; charset=utf-8"}],
      body => Body};
html_handler(_Request) ->
    {ok, Body} = file:read_file(filename:join(["apps", "scrapling", "test", "fixtures", "parser_base.html"])),
    #{status => 200,
      headers => [{"content-type", "text/html; charset=utf-8"}],
      body => Body}.
