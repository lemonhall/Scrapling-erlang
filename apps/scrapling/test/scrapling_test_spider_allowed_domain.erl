-module(scrapling_test_spider_allowed_domain).

-export([start_urls/0, allowed_domains/0, parse/1]).

start_urls() ->
    ["https://example.com/seed"].

allowed_domains() ->
    [<<"example.com">>].

parse(Response) ->
    [#{kind => <<"seed">>, title => to_binary(first_text("h1::text", Response))},
     scrapling_request:new("https://outside.test/blocked")].

first_text(Selector, Response) ->
    case scrapling_response:css(Selector, Response) of
        [Node | _] -> scrapling_selector:get(Node);
        [] -> ""
    end.

to_binary(Value) when is_binary(Value) ->
    Value;
to_binary(Value) when is_list(Value) ->
    unicode:characters_to_binary(Value).
