-module(scrapling_fetcher_tests).

-include_lib("eunit/include/eunit.hrl").

fetcher_get_response_test() ->
    {ok, Body} = file:read_file(fixture_path("parser_base.html")),
    {ok, Server, BaseUrl} = scrapling_test_httpd:start_link(fun html_handler/1),
    try
        Response = scrapling_fetcher:get(BaseUrl ++ "/"),
        ?assertEqual(200, scrapling_response:status_code(Response)),
        ?assertEqual(Body, scrapling_response:body(Response)),
        ?assertEqual(<<"GET">>, scrapling_response:method(Response)),
        ?assertEqual(list_to_binary(BaseUrl ++ "/"), scrapling_response:url(Response)),
        ?assertEqual("text/html; charset=utf-8", scrapling_response:header("content-type", Response)),
        Headings = scrapling_response:css("h1::text", Response),
        ?assertEqual(["Scrapling Erlang"], [scrapling_selector:get(Node) || Node <- Headings])
    after
        ok = scrapling_test_httpd:stop(Server)
    end.

fetcher_http_methods_test() ->
    {ok, Server, BaseUrl} = scrapling_test_httpd:start_link(fun echo_handler/1),
    try
        Post = scrapling_fetcher:post(
                 BaseUrl ++ "/echo",
                 <<"alpha=1">>,
                 #{headers => [{"x-test", "static-post"}], content_type => "application/x-www-form-urlencoded"}),
        ?assertEqual(<<"POST|static-post|alpha=1">>, scrapling_response:body(Post)),

        Put = scrapling_fetcher:put(
                BaseUrl ++ "/echo",
                <<"beta=2">>,
                #{headers => [{"x-test", "static-put"}], content_type => "text/plain"}),
        ?assertEqual(<<"PUT|static-put|beta=2">>, scrapling_response:body(Put)),

        Delete = scrapling_fetcher:delete(
                   BaseUrl ++ "/echo",
                   <<"gamma=3">>,
                   #{headers => [{"x-test", "static-delete"}], content_type => "text/plain"}),
        ?assertEqual(<<"DELETE|static-delete|gamma=3">>, scrapling_response:body(Delete))
    after
        ok = scrapling_test_httpd:stop(Server)
    end.

fixture_path(Name) ->
    filename:join(["apps", "scrapling", "test", "fixtures", Name]).

html_handler(_Request) ->
    {ok, Body} = file:read_file(fixture_path("parser_base.html")),
    #{status => 200,
      headers => [{"content-type", "text/html; charset=utf-8"}],
      body => Body}.

echo_handler(Request) ->
    Method = maps:get(method, Request),
    Headers = maps:get(headers, Request),
    Body = maps:get(body, Request),
    HeaderValue = maps:get("x-test", Headers, ""),
    #{status => 200,
      headers => [{"content-type", "text/plain"}],
      body => <<(list_to_binary(Method))/binary, "|", (list_to_binary(HeaderValue))/binary, "|", Body/binary>>}.
