-module(scrapling_test_spider_blocked_retry).

-export([start_requests/0, allowed_domains/0, max_blocked_retries/0, parse/1, retry_blocked_request/2]).

start_requests() ->
    [scrapling_request:new("https://example.com/blocked", #{priority => 5, proxy => <<"http://proxy.local:8080">>})].

allowed_domains() ->
    [<<"example.com">>].

max_blocked_retries() ->
    1.

parse(Response) ->
    [#{kind => <<"blocked-retry">>, title => to_binary(first_text("h1::text", Response))}].

retry_blocked_request(Request, _Response) ->
    Request#{url => <<"https://example.com/recovered">>,
             meta => (scrapling_request:meta(Request))#{retry_strategy => <<"url_shift">>}}.

first_text(Selector, Response) ->
    case scrapling_response:css(Selector, Response) of
        [Node | _] -> scrapling_selector:get(Node);
        [] -> ""
    end.

to_binary(Value) when is_binary(Value) ->
    Value;
to_binary(Value) when is_list(Value) ->
    unicode:characters_to_binary(Value).
