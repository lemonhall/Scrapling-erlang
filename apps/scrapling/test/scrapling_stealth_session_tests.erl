-module(scrapling_stealth_session_tests).

-include_lib("eunit/include/eunit.hrl").

stealth_session_applies_default_options_test() ->
    {ok, Server, BaseUrl} = scrapling_test_httpd:start_link(fun html_handler/1),
    {ok, Session} = scrapling_stealth_session:start_link(#{wait_selector => "h1", block_webrtc => true}),
    try
        Response = scrapling_stealth_session:fetch(Session, BaseUrl ++ "/"),
        ?assertEqual(200, scrapling_response:status_code(Response)),
        ?assertEqual(true, maps:get(stealth, scrapling_response:meta(Response))),
        ?assertEqual(true, maps:get(block_webrtc, scrapling_response:meta(Response)))
    after
        ok = scrapling_stealth_session:stop(Session),
        ok = scrapling_test_httpd:stop(Server)
    end.

stealth_session_request_override_test() ->
    {ok, Server, BaseUrl} = scrapling_test_httpd:start_link(fun html_handler/1),
    {ok, Session} = scrapling_stealth_session:start_link(#{wait_selector => "article"}),
    try
        Response = scrapling_stealth_session:fetch(Session, BaseUrl ++ "/", #{wait_selector => "h1", allow_webgl => false}),
        ?assertEqual(200, scrapling_response:status_code(Response)),
        ?assertEqual(false, maps:get(allow_webgl, scrapling_response:meta(Response)))
    after
        ok = scrapling_stealth_session:stop(Session),
        ok = scrapling_test_httpd:stop(Server)
    end.

html_handler(_Request) ->
    {ok, Body} = file:read_file(filename:join(["apps", "scrapling", "test", "fixtures", "parser_base.html"])),
    #{status => 200,
      headers => [{"content-type", "text/html; charset=utf-8"}],
      body => Body}.
