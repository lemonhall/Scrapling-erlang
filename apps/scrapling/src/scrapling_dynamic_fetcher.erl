-module(scrapling_dynamic_fetcher).

-export([fetch/1, fetch/2]).

fetch(Url) ->
    fetch(Url, #{}).

fetch(Url, Opts) when is_map(Opts) ->
    case scrapling_browser_port:fetch(Url, Opts) of
        {ok, BrowserResponse} ->
            scrapling_response:new(
              maps:get(status_code, BrowserResponse),
              maps:get(reason_phrase, BrowserResponse),
              maps:get(headers, BrowserResponse),
              maps:get(body, BrowserResponse),
              maps:get(url, BrowserResponse),
              maps:get(method, BrowserResponse),
              [],
              maps:get(meta, BrowserResponse, #{}));
        {error, Error} ->
            erlang:error({browser_fetch_failed, Error})
    end.
