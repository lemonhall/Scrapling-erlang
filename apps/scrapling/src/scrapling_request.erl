-module(scrapling_request).

-export([
    new/1,
    new/2,
    copy/1,
    is_request/1,
    url/1,
    sid/1,
    callback/1,
    priority/1,
    dont_filter/1,
    meta/1,
    session_opts/1,
    domain/1,
    fingerprint/1
]).

new(Url) ->
    new(Url, #{}).

new(Url, Opts) when is_map(Opts) ->
    SessionKeys = [method, body, data, json, headers, extra_headers, proxy, timeout, wait_selector,
                   wait_selector_state, network_idle, blocked_domains, cdp_url],
    SessionOpts = maps:with(SessionKeys, Opts),
    #{url => to_binary(Url),
      sid => to_binary(maps:get(sid, Opts, <<>>)),
      callback => maps:get(callback, Opts, undefined),
      priority => maps:get(priority, Opts, 0),
      dont_filter => maps:get(dont_filter, Opts, false),
      meta => maps:get(meta, Opts, #{}),
      retry_count => maps:get(retry_count, Opts, 0),
      session_opts => SessionOpts}.

copy(Request) ->
    new(
      url(Request),
      (session_opts(Request))#{sid => sid(Request),
                              callback => callback(Request),
                              priority => priority(Request),
                              dont_filter => dont_filter(Request),
                              meta => maps:merge(#{}, meta(Request)),
                              retry_count => maps:get(retry_count, Request, 0)}).

is_request(#{url := _Url, session_opts := _SessionOpts}) ->
    true;
is_request(_) ->
    false.

url(Request) ->
    maps:get(url, Request).

sid(Request) ->
    maps:get(sid, Request, <<>>).

callback(Request) ->
    maps:get(callback, Request, undefined).

priority(Request) ->
    maps:get(priority, Request, 0).

dont_filter(Request) ->
    maps:get(dont_filter, Request, false).

meta(Request) ->
    maps:get(meta, Request, #{}).

session_opts(Request) ->
    maps:get(session_opts, Request, #{}).

domain(Request) ->
    Parsed = uri_string:parse(to_list(url(Request))),
    Host = to_binary(maps:get(host, Parsed, <<>>)),
    case maps:get(port, Parsed, undefined) of
        undefined -> Host;
        Port -> <<Host/binary, ":", (integer_to_binary(Port))/binary>>
    end.

fingerprint(Request) ->
    Data = #{sid => sid(Request),
             method => normalized_method(session_opts(Request)),
             url => normalized_url(url(Request)),
             body => normalized_body(session_opts(Request))},
    crypto:hash(sha, term_to_binary(Data)).

normalized_method(SessionOpts) ->
    Method = maps:get(method, SessionOpts, get),
    to_binary(string:uppercase(to_list(Method))).

normalized_url(Url) ->
    Parsed = uri_string:parse(to_list(Url)),
    to_binary(uri_string:recompose(maps:remove(fragment, Parsed))).

normalized_body(SessionOpts) ->
    case maps:get(body, SessionOpts, undefined) of
        undefined -> normalized_body_from_data(SessionOpts);
        Body -> to_binary(Body)
    end.

normalized_body_from_data(SessionOpts) ->
    case maps:get(data, SessionOpts, undefined) of
        undefined -> normalized_body_from_json(SessionOpts);
        Data -> term_to_binary(Data)
    end.

normalized_body_from_json(SessionOpts) ->
    case maps:get(json, SessionOpts, undefined) of
        undefined -> <<>>;
        Json -> term_to_binary(Json)
    end.

to_binary(Value) when is_binary(Value) ->
    Value;
to_binary(Value) when is_list(Value) ->
    unicode:characters_to_binary(Value);
to_binary(Value) when is_atom(Value) ->
    atom_to_binary(Value, utf8);
to_binary(Value) when is_integer(Value) ->
    integer_to_binary(Value).

to_list(Value) when is_list(Value) ->
    Value;
to_list(Value) when is_binary(Value) ->
    binary_to_list(Value);
to_list(Value) when is_atom(Value) ->
    atom_to_list(Value);
to_list(Value) when is_integer(Value) ->
    integer_to_list(Value).
