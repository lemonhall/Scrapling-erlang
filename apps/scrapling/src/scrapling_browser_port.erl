-module(scrapling_browser_port).

-export([ping/0, fetch/1, fetch/2]).

ping() ->
    case call([{"command", "ping"}]) of
        {ok, Response} ->
            {ok,
             #{name => to_binary(maps:get("name", Response)),
               protocol_version => list_to_integer(maps:get("protocol_version", Response, "1"))}};
        Error ->
            Error
    end.

fetch(Url) ->
    fetch(Url, #{}).

fetch(Url, Opts) when is_map(Opts) ->
    case validate_fetch_opts(Opts) of
        ok ->
            Params = fetch_params(Url, Opts),
            case call(Params) of
                {ok, Response} ->
                    {ok,
                     #{status_code => list_to_integer(maps:get("status_code", Response)),
                       reason_phrase => to_binary(maps:get("reason_phrase", Response, "OK")),
                       headers => decode_headers(maps:get("headers_b64", Response, "")),
                       body => decode_body(maps:get("body_b64", Response, "")),
                       url => to_binary(maps:get("url", Response, Url)),
                       method => to_binary(string:uppercase(maps:get("method", Response, "GET"))),
                       meta => response_meta(Response)}};
                {error, Error} ->
                    {error, Error}
            end;
        {error, Error} ->
            {error, Error}
    end.

validate_fetch_opts(Opts) ->
    validate_cdp_url(maps:get(cdp_url, Opts, undefined)).

validate_cdp_url(undefined) ->
    ok;
validate_cdp_url(CdpUrl) ->
    Parsed = uri_string:parse(to_list(CdpUrl)),
    case maps:get(scheme, Parsed, undefined) of
        "ws" -> validate_cdp_host(Parsed);
        "wss" -> validate_cdp_host(Parsed);
        _ ->
            {error,
             #{type => <<"invalid_cdp_url">>,
               message => <<"CDP URL must use 'ws://' or 'wss://' scheme">>}}
    end.

validate_cdp_host(Parsed) ->
    case maps:get(host, Parsed, <<>>) of
        <<>> -> invalid_cdp_hostname_error();
        [] -> invalid_cdp_hostname_error();
        _ -> unsupported_cdp_url_error()
    end.

invalid_cdp_hostname_error() ->
    {error,
     #{type => <<"invalid_cdp_url">>,
       message => <<"Invalid hostname for the CDP URL">>}}.

unsupported_cdp_url_error() ->
    {error,
     #{type => <<"unsupported_cdp_url">>,
       message => <<"cdp_url is not supported by the current browser sidecar">>}}.

fetch_params(Url, Opts) ->
    Base = [{"command", "fetch"},
            {"url", to_list(Url)},
            {"method", string:uppercase(to_list(maps:get(method, Opts, "GET")))},
            {"timeout_ms", integer_to_list(maps:get(timeout, Opts, 30000))}],
    WithWaitSelector = maybe_add_param("wait_selector", maps:get(wait_selector, Opts, undefined), Base),
    WithWaitSelectorState = maybe_add_param("wait_selector_state", maps:get(wait_selector_state, Opts, undefined), WithWaitSelector),
    WithHeadless = maybe_add_param("headless", bool_string(maps:get(headless, Opts, true)), WithWaitSelectorState),
    WithWait = maybe_add_param("wait_ms", int_to_list(maps:get(wait, Opts, undefined)), WithHeadless),
    WithNetworkIdle = maybe_add_param("network_idle", bool_string(maps:get(network_idle, Opts, undefined)), WithWait),
    WithBlocked = maybe_add_param("blocked_domains", blocked_domains_value(maps:get(blocked_domains, Opts, undefined)), WithNetworkIdle),
    WithProxy = maybe_add_param("proxy", proxy_value(maps:get(proxy, Opts, undefined)), WithBlocked),
    maybe_add_param("headers_b64", encode_headers(maps:get(headers, Opts, [])), WithProxy).

call(Params) ->
    Python = python_executable(),
    Sidecar = sidecar_path(),
    Port = open_port(
             {spawn_executable, Python},
             [binary, exit_status, use_stdio, stderr_to_stdout, hide, eof, {args, ["-u", Sidecar]}]),
    Request = iolist_to_binary([uri_string:compose_query(Params), "\n"]),
    true = port_command(Port, Request),
    collect_port_output(Port, <<>>).

collect_port_output(Port, Acc) ->
    receive
        {Port, {data, Data}} ->
            collect_port_output(Port, <<Acc/binary, Data/binary>>);
        {Port, eof} ->
            collect_port_output(Port, Acc);
        {Port, {exit_status, 0}} ->
            parse_response(Acc);
        {Port, {exit_status, Status}} ->
            {error, #{type => <<"sidecar_exit">>, status => Status, output => Acc}}
    after 30000 ->
        port_close(Port),
        {error, #{type => <<"sidecar_timeout">>}}
    end.

parse_response(Binary) ->
    Text = string:trim(binary_to_list(Binary)),
    Response = maps:from_list(uri_string:dissect_query(Text)),
    case maps:get("ok", Response, "false") of
        "true" -> {ok, Response};
        _ ->
            {error,
             #{type => to_binary(maps:get("type", Response, "sidecar_error")),
               message => to_binary(maps:get("message", Response, "unknown error"))}}
    end.

response_meta(Response) ->
    #{engine => to_binary(maps:get("engine", Response, "python-sidecar")),
      headless => string_to_bool(maps:get("headless", Response, "true"))}.

decode_body("") ->
    <<>>;
decode_body(Value) ->
    base64:decode(to_binary(Value)).

decode_headers("") ->
    [];
decode_headers(Value) ->
    Lines = string:split(binary_to_list(base64:decode(to_binary(Value))), "\n", all),
    [{Name, HeaderValue} || Line <- Lines,
                           Line =/= [],
                           {Name, HeaderValue} <- [split_header(Line)]].

split_header(Line) ->
    case string:split(Line, ":", leading) of
        [Name, Value] -> {string:lowercase(string:trim(Name)), string:trim(Value)};
        [Name] -> {string:lowercase(string:trim(Name)), ""}
    end.

encode_headers(undefined) ->
    undefined;
encode_headers(Headers) when is_map(Headers) ->
    encode_headers(maps:to_list(Headers));
encode_headers([]) ->
    undefined;
encode_headers(Headers) when is_list(Headers) ->
    base64:encode_to_string(iolist_to_binary([[to_list(Name), ":", to_list(Value), "\n"] || {Name, Value} <- Headers])).

maybe_add_param(_Key, undefined, Params) ->
    Params;
maybe_add_param(_Key, [], Params) ->
    Params;
maybe_add_param(Key, Value, Params) ->
    Params ++ [{Key, Value}].

blocked_domains_value(undefined) ->
    undefined;
blocked_domains_value(Values) when is_list(Values) ->
    string:join([to_list(Value) || Value <- Values], ",").

proxy_value(undefined) ->
    undefined;
proxy_value(#{server := Server}) ->
    to_list(Server);
proxy_value(Value) ->
    to_list(Value).

bool_string(undefined) ->
    undefined;
bool_string(true) ->
    "true";
bool_string(false) ->
    "false".

int_to_list(undefined) ->
    undefined;
int_to_list(Value) when is_integer(Value) ->
    integer_to_list(Value);
int_to_list(Value) ->
    to_list(Value).

string_to_bool("true") -> true;
string_to_bool("false") -> false;
string_to_bool(Value) when is_binary(Value) -> string_to_bool(binary_to_list(Value));
string_to_bool(_) -> false.

sidecar_path() ->
    filename:join([priv_dir(), "browser", "browser_sidecar.py"]).

priv_dir() ->
    case code:priv_dir(scrapling) of
        {error, bad_name} -> filename:join(["apps", "scrapling", "priv"]);
        Path -> Path
    end.

python_executable() ->
    case os:find_executable("python") of
        false -> erlang:error({python_not_found, python});
        Path -> Path
    end.

to_list(Value) when is_list(Value) ->
    Value;
to_list(Value) when is_binary(Value) ->
    binary_to_list(Value);
to_list(Value) when is_atom(Value) ->
    atom_to_list(Value);
to_list(Value) when is_integer(Value) ->
    integer_to_list(Value).

to_binary(Value) when is_binary(Value) ->
    Value;
to_binary(Value) when is_list(Value) ->
    unicode:characters_to_binary(Value);
to_binary(Value) when is_atom(Value) ->
    atom_to_binary(Value, utf8).
