-module(scrapling_browser_contract_tests).

-include_lib("eunit/include/eunit.hrl").

browser_port_ping_test() ->
    {ok, Info} = scrapling_browser_port:ping(),
    ?assertEqual(<<"scrapling-browser-sidecar">>, maps:get(name, Info)),
    ?assertEqual(1, maps:get(protocol_version, Info)).

browser_port_fetch_contract_test() ->
    {ok, Server, BaseUrl} = scrapling_test_httpd:start_link(fun html_handler/1),
    try
        {ok, Response} = scrapling_browser_port:fetch(BaseUrl ++ "/", #{headless => true, wait_selector => "h1"}),
        ?assertEqual(200, maps:get(status_code, Response)),
        ?assertEqual(<<"GET">>, maps:get(method, Response)),
        ?assertMatch(<<_/binary>>, maps:get(body, Response)),
        ?assertEqual(<<"python-sidecar">>, maps:get(engine, maps:get(meta, Response)))
    after
        ok = scrapling_test_httpd:stop(Server)
    end.

browser_port_wait_selector_failure_test() ->
    {ok, Server, BaseUrl} = scrapling_test_httpd:start_link(fun html_handler/1),
    try
        {error, Error} = scrapling_browser_port:fetch(BaseUrl ++ "/", #{wait_selector => "article"}),
        ?assertEqual(<<"selector_not_found">>, maps:get(type, Error))
    after
        ok = scrapling_test_httpd:stop(Server)
    end.

browser_port_invalid_cdp_url_test() ->
    {error, Error} = scrapling_browser_port:fetch("http://example.com", #{cdp_url => "blahblah"}),
    ?assertEqual(<<"invalid_cdp_url">>, maps:get(type, Error)).

browser_port_unsupported_cdp_url_test() ->
    {error, Error} = scrapling_browser_port:fetch("http://example.com", #{cdp_url => "ws://localhost:9222/devtools/browser/123"}),
    ?assertEqual(<<"unsupported_cdp_url">>, maps:get(type, Error)).

browser_port_blocked_domain_exact_test() ->
    {error, Error} = scrapling_browser_port:fetch(
                       "http://example.invalid",
                       #{blocked_domains => ["example.invalid"]}),
    ?assertEqual(<<"blocked_domain">>, maps:get(type, Error)).

browser_port_blocked_domain_subdomain_test() ->
    {error, Error} = scrapling_browser_port:fetch(
                       "http://www.example.invalid",
                       #{blocked_domains => ["example.invalid"]}),
    ?assertEqual(<<"blocked_domain">>, maps:get(type, Error)).

html_handler(_Request) ->
    {ok, Body} = file:read_file(filename:join(["apps", "scrapling", "test", "fixtures", "parser_base.html"])),
    #{status => 200,
      headers => [{"content-type", "text/html; charset=utf-8"}],
      body => Body}.
