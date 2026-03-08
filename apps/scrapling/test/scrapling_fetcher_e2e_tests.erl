-module(scrapling_fetcher_e2e_tests).

-include_lib("eunit/include/eunit.hrl").

local_http_fixture_e2e_test() ->
    {ok, Server, BaseUrl} = scrapling_test_httpd:start_link(fun html_handler/1),
    try
        Response = scrapling_fetcher:get(BaseUrl ++ "/"),
        ?assertEqual(200, scrapling_response:status_code(Response)),
        ?assertEqual(["Read docs"], [scrapling_selector:get(Node) || Node <- scrapling_response:css("a::text", Response)])
    after
        ok = scrapling_test_httpd:stop(Server)
    end.

html_handler(_Request) ->
    {ok, Body} = file:read_file(filename:join(["apps", "scrapling", "test", "fixtures", "parser_base.html"])),
    #{status => 200,
      headers => [{"content-type", "text/html; charset=utf-8"}],
      body => Body}.
