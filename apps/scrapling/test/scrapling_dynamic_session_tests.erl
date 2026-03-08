-module(scrapling_dynamic_session_tests).

-include_lib("eunit/include/eunit.hrl").

dynamic_session_applies_default_options_test() ->
    {ok, Server, BaseUrl} = scrapling_test_httpd:start_link(fun html_handler/1),
    {ok, Session} = scrapling_dynamic_session:start_link(#{headless => true, wait_selector => "h1"}),
    try
        Response = scrapling_dynamic_session:fetch(Session, BaseUrl ++ "/"),
        ?assertEqual(200, scrapling_response:status_code(Response)),
        ?assertEqual(true, maps:get(headless, scrapling_response:meta(Response)))
    after
        ok = scrapling_dynamic_session:stop(Session),
        ok = scrapling_test_httpd:stop(Server)
    end.

dynamic_session_request_override_test() ->
    {ok, Server, BaseUrl} = scrapling_test_httpd:start_link(fun html_handler/1),
    {ok, Session} = scrapling_dynamic_session:start_link(#{wait_selector => "article"}),
    try
        Response = scrapling_dynamic_session:fetch(Session, BaseUrl ++ "/", #{wait_selector => "h1"}),
        ?assertEqual(200, scrapling_response:status_code(Response)),
        ?assertEqual(["Scrapling Erlang"], [scrapling_selector:get(Node) || Node <- scrapling_response:css("h1::text", Response)])
    after
        ok = scrapling_dynamic_session:stop(Session),
        ok = scrapling_test_httpd:stop(Server)
    end.

html_handler(_Request) ->
    {ok, Body} = file:read_file(filename:join(["apps", "scrapling", "test", "fixtures", "parser_base.html"])),
    #{status => 200,
      headers => [{"content-type", "text/html; charset=utf-8"}],
      body => Body}.
