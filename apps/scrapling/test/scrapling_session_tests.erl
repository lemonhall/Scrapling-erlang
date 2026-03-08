-module(scrapling_session_tests).

-include_lib("eunit/include/eunit.hrl").

session_keeps_headers_and_cookies_test() ->
    {ok, Server, BaseUrl} = scrapling_test_httpd:start_link(fun cookie_handler/1),
    {ok, Session} = scrapling_fetcher_session:start_link(#{headers => [{"x-session", "alive"}]}),
    try
        _ = scrapling_fetcher_session:get(Session, BaseUrl ++ "/set-cookie"),
        Response = scrapling_fetcher_session:get(Session, BaseUrl ++ "/check"),
        ?assertEqual(<<"sid=abc123|alive">>, scrapling_response:body(Response)),
        ?assertEqual(#{"sid" => "abc123"}, scrapling_response:cookies(Response))
    after
        ok = scrapling_fetcher_session:stop(Session),
        ok = scrapling_test_httpd:stop(Server)
    end.

proxy_rotator_cyclic_and_custom_test() ->
    {ok, ProxyOne, ProxyOneUrl} = scrapling_test_httpd:start_link(fun proxy_one_handler/1),
    {ok, ProxyTwo, ProxyTwoUrl} = scrapling_test_httpd:start_link(fun proxy_two_handler/1),
    {ok, TargetServer, TargetUrl} = scrapling_test_httpd:start_link(fun ignored_target_handler/1),
    Rotator = scrapling_proxy_rotator:new([ProxyOneUrl, ProxyTwoUrl]),
    {ok, Session} = scrapling_fetcher_session:start_link(#{proxy_rotator => Rotator}),
    try
        ResponseOne = scrapling_fetcher_session:get(Session, TargetUrl ++ "/proxy"),
        ?assertEqual(<<"proxy-one">>, scrapling_response:body(ResponseOne)),
        ?assertEqual(list_to_binary(ProxyOneUrl), maps:get(proxy, scrapling_response:meta(ResponseOne))),

        ResponseTwo = scrapling_fetcher_session:get(Session, TargetUrl ++ "/proxy"),
        ?assertEqual(<<"proxy-two">>, scrapling_response:body(ResponseTwo)),
        ?assertEqual(list_to_binary(ProxyTwoUrl), maps:get(proxy, scrapling_response:meta(ResponseTwo))),

        Custom = scrapling_proxy_rotator:new(
                   [ProxyOneUrl, ProxyTwoUrl],
                   fun(Proxies, _Index) -> {lists:last(Proxies), 0} end),
        {Chosen, _NextRotator} = scrapling_proxy_rotator:next(Custom),
        ?assertEqual(ProxyTwoUrl, Chosen)
    after
        ok = scrapling_fetcher_session:stop(Session),
        ok = scrapling_test_httpd:stop(TargetServer),
        ok = scrapling_test_httpd:stop(ProxyTwo),
        ok = scrapling_test_httpd:stop(ProxyOne)
    end.

cookie_handler(Request) ->
    case maps:get(path, Request) of
        "/set-cookie" ->
            #{status => 200,
              headers => [{"content-type", "text/plain"}, {"set-cookie", "sid=abc123; Path=/"}],
              body => <<"cookie-set">>};
        "/check" ->
            Headers = maps:get(headers, Request),
            Cookie = maps:get("cookie", Headers, ""),
            SessionHeader = maps:get("x-session", Headers, ""),
            #{status => 200,
              headers => [{"content-type", "text/plain"}, {"set-cookie", "sid=abc123; Path=/"}],
              body => <<(list_to_binary(Cookie))/binary, "|", (list_to_binary(SessionHeader))/binary>>}
    end.

proxy_one_handler(_Request) ->
    #{status => 200, headers => [{"content-type", "text/plain"}], body => <<"proxy-one">>}.

proxy_two_handler(_Request) ->
    #{status => 200, headers => [{"content-type", "text/plain"}], body => <<"proxy-two">>}.

ignored_target_handler(_Request) ->
    #{status => 200, headers => [{"content-type", "text/plain"}], body => <<"target">>}.
