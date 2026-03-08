-module(scrapling_test_spider_minimal).

-export([start_urls/0, allowed_domains/0, parse/1, parse_detail/1]).

start_urls() ->
    ["https://example.com/list"].

allowed_domains() ->
    [<<"example.com">>].

parse(Response) ->
    Title = first_text("h1::text", Response),
    DetailUrl = first_text("a.next::attr(href)", Response),
    [#{kind => <<"list">>, title => to_binary(Title)},
     scrapling_request:new(DetailUrl, #{callback => parse_detail})].

parse_detail(Response) ->
    [#{kind => <<"detail">>, title => to_binary(first_text("h1::text", Response))}].

first_text(Selector, Response) ->
    case scrapling_response:css(Selector, Response) of
        [Node | _] -> scrapling_selector:get(Node);
        [] -> ""
    end.

to_binary(Value) when is_binary(Value) ->
    Value;
to_binary(Value) when is_list(Value) ->
    unicode:characters_to_binary(Value).
