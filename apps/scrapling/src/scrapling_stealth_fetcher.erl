-module(scrapling_stealth_fetcher).

-export([fetch/1, fetch/2]).

fetch(Url) ->
    fetch(Url, #{}).

fetch(Url, Opts) when is_map(Opts) ->
    StealthOpts = Opts#{stealth => true},
    case scrapling_browser_port:fetch(Url, StealthOpts) of
        {ok, BrowserResponse} ->
            Meta0 = maps:get(meta, BrowserResponse, #{}),
            Meta = Meta0#{stealth => true,
                          block_webrtc => maps:get(block_webrtc, Opts, undefined),
                          allow_webgl => maps:get(allow_webgl, Opts, undefined)},
            scrapling_response:new(
              maps:get(status_code, BrowserResponse),
              maps:get(reason_phrase, BrowserResponse),
              maps:get(headers, BrowserResponse),
              maps:get(body, BrowserResponse),
              maps:get(url, BrowserResponse),
              maps:get(method, BrowserResponse),
              [],
              Meta);
        {error, Error} ->
            erlang:error({stealth_fetch_failed, Error})
    end.
