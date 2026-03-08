-module(scrapling_fetcher).

-export([
    get/1,
    get/2,
    post/2,
    post/3,
    put/2,
    put/3,
    delete/1,
    delete/2,
    delete/3,
    request/2,
    request/3
]).

get(Url) ->
    request(get, Url, #{}).

get(Url, Opts) when is_map(Opts) ->
    request(get, Url, Opts).

post(Url, Opts) when is_map(Opts) ->
    request(post, Url, Opts);
post(Url, Body) ->
    request(post, Url, #{body => Body}).

post(Url, Body, Opts) when is_map(Opts) ->
    request(post, Url, Opts#{body => Body}).

put(Url, Opts) when is_map(Opts) ->
    request(put, Url, Opts);
put(Url, Body) ->
    request(put, Url, #{body => Body}).

put(Url, Body, Opts) when is_map(Opts) ->
    request(put, Url, Opts#{body => Body}).

delete(Url) ->
    request(delete, Url, #{}).

delete(Url, Opts) when is_map(Opts) ->
    request(delete, Url, Opts);
delete(Url, Body) ->
    request(delete, Url, #{body => Body}).

delete(Url, Body, Opts) when is_map(Opts) ->
    request(delete, Url, Opts#{body => Body}).

request(Method, Url) ->
    request(Method, Url, #{}).

request(Method, Url, #{session := Session} = Opts) when is_pid(Session) ->
    scrapling_fetcher_session:request(Session, Method, Url, maps:remove(session, Opts));
request(Method, Url, Opts) when is_map(Opts) ->
    ensure_started(),
    MethodAtom = normalize_method(Method),
    FinalUrl = build_url(Url, maps:get(params, Opts, undefined)),
    Headers0 = normalize_headers(maps:get(headers, Opts, [])),
    Cookies = normalize_cookies(maps:get(cookies, Opts, #{})),
    Headers1 = add_cookie_header(Headers0, Cookies),
    {Body, ContentType} = payload_from_opts(Opts),
    Headers2 = maybe_add_content_type_header(Headers1, Body, ContentType),
    Request = build_request(MethodAtom, FinalUrl, Headers2, Body, ContentType),
    HttpOptions = build_http_options(Opts),
    RequestOptions = [{body_format, binary}],
    Meta = effective_meta(Opts),
    case perform_request(
           MethodAtom,
           Request,
           HttpOptions,
           RequestOptions,
           maps:get(proxy, Opts, undefined),
           maps:get(profile, Opts, undefined)) of
        {ok, {{_Version, StatusCode, ReasonPhrase}, ResponseHeaders, ResponseBody}} ->
            scrapling_response:new(
              StatusCode,
              ReasonPhrase,
              ResponseHeaders,
              ResponseBody,
              FinalUrl,
              MethodAtom,
              Headers2,
              Meta);
        {error, Reason} ->
            erlang:error({http_request_failed, MethodAtom, FinalUrl, Reason})
    end.

ensure_started() ->
    ok = ensure_started(inets),
    ok = ensure_started(ssl).

ensure_started(App) ->
    case application:ensure_all_started(App) of
        {ok, _} -> ok;
        {error, {already_started, App}} -> ok;
        {error, {already_started, _}} -> ok
    end.

normalize_method(Method) when is_atom(Method) ->
    Method;
normalize_method(Method) when is_binary(Method) ->
    list_to_existing_atom(string:lowercase(binary_to_list(Method)));
normalize_method(Method) when is_list(Method) ->
    list_to_existing_atom(string:lowercase(Method)).

build_url(Url, undefined) ->
    to_list(Url);
build_url(Url, Params) ->
    BaseUrl = to_list(Url),
    Query = uri_string:compose_query(normalize_query(Params)),
    case Query of
        [] -> BaseUrl;
        _ ->
            Separator = case lists:member($?, BaseUrl) of true -> "&"; false -> "?" end,
            BaseUrl ++ Separator ++ Query
    end.

normalize_query(Params) when is_map(Params) ->
    [{to_list(Key), to_list(Value)} || {Key, Value} <- maps:to_list(Params)];
normalize_query(Params) when is_list(Params) ->
    [{to_list(Key), to_list(Value)} || {Key, Value} <- Params].

normalize_headers(Headers) when is_map(Headers) ->
    normalize_headers(maps:to_list(Headers));
normalize_headers(Headers) when is_list(Headers) ->
    [{normalize_header_name(Name), to_list(Value)} || {Name, Value} <- Headers].

normalize_cookies(Cookies) when is_map(Cookies) ->
    #{to_list(Name) => to_list(Value) || Name := Value <- Cookies};
normalize_cookies(Cookies) when is_list(Cookies) ->
    maps:from_list([{to_list(Name), to_list(Value)} || {Name, Value} <- Cookies]);
normalize_cookies(undefined) ->
    #{}.

add_cookie_header(Headers, Cookies) when map_size(Cookies) =:= 0 ->
    Headers;
add_cookie_header(Headers, Cookies) ->
    case lists:keymember("cookie", 1, Headers) of
        true -> Headers;
        false -> Headers ++ [{"cookie", encode_cookie_header(Cookies)}]
    end.

encode_cookie_header(Cookies) ->
    string:join([Name ++ "=" ++ Value || {Name, Value} <- maps:to_list(Cookies)], "; ").

payload_from_opts(Opts) ->
    case maps:get(data, Opts, undefined) of
        undefined ->
            case maps:get(body, Opts, undefined) of
                undefined -> {undefined, undefined};
                Body -> {to_binary(Body), content_type_from_opts(Opts)}
            end;
        Data ->
            Query = uri_string:compose_query(normalize_query(Data)),
            {unicode:characters_to_binary(Query), "application/x-www-form-urlencoded"}
    end.

content_type_from_opts(Opts) ->
    to_list(maps:get(content_type, Opts, "application/octet-stream")).

maybe_add_content_type_header(Headers, undefined, _ContentType) ->
    Headers;
maybe_add_content_type_header(Headers, _Body, ContentType) ->
    case lists:keymember("content-type", 1, Headers) of
        true -> Headers;
        false -> Headers ++ [{"content-type", ContentType}]
    end.

build_request(get, Url, Headers, _Body, _ContentType) ->
    {Url, Headers};
build_request(delete, Url, Headers, undefined, _ContentType) ->
    {Url, Headers};
build_request(_Method, Url, Headers, Body, ContentType) ->
    {Url, Headers, ContentType, body_or_empty(Body)}.

body_or_empty(undefined) ->
    <<>>;
body_or_empty(Body) ->
    Body.

build_http_options(Opts) ->
    timeout_option(Opts) ++
    redirect_option(Opts).

timeout_option(Opts) ->
    case maps:get(timeout, Opts, undefined) of
        undefined -> [];
        Timeout -> [{timeout, Timeout}]
    end.

redirect_option(Opts) ->
    case maps:get(follow_redirects, Opts, undefined) of
        undefined -> [];
        Value -> [{autoredirect, Value}]
    end.

perform_request(Method, Request, HttpOptions, RequestOptions, undefined, undefined) ->
    httpc:request(Method, Request, HttpOptions, RequestOptions);
perform_request(Method, Request, HttpOptions, RequestOptions, undefined, Profile) ->
    httpc:request(Method, Request, HttpOptions, RequestOptions, Profile);
perform_request(Method, Request, HttpOptions, RequestOptions, Proxy, undefined) ->
    with_proxy_profile(
      Proxy,
      fun(Profile) ->
          httpc:request(Method, Request, HttpOptions, RequestOptions, Profile)
      end);
perform_request(Method, Request, HttpOptions, RequestOptions, Proxy, Profile) ->
    ok = httpc:set_options([{proxy, {proxy_target(Proxy), []}}], Profile),
    httpc:request(Method, Request, HttpOptions, RequestOptions, Profile).

with_proxy_profile(Proxy, Fun) ->
    {ok, Profile} = httpc:start_standalone([{profile, scrapling_proxy_request}, {proxy, {proxy_target(Proxy), []}}]),
    try Fun(Profile)
    after
        ok = httpc:stop_service(Profile)
    end.

proxy_target(Proxy) when is_map(Proxy) ->
    proxy_target(maps:get(server, Proxy));
proxy_target(Proxy) ->
    Parsed = uri_string:parse(to_list(Proxy)),
    Host = maps:get(host, Parsed),
    Port = maps:get(port, Parsed, default_port(maps:get(scheme, Parsed, "http"))),
    {Host, Port}.

default_port("https") -> 443;
default_port(_) -> 80.

effective_meta(Opts) ->
    Meta = maps:get(meta, Opts, #{}),
    case maps:get(proxy, Opts, undefined) of
        undefined -> Meta;
        Proxy -> Meta#{proxy => to_binary(proxy_server(Proxy))}
    end.

proxy_server(Proxy) when is_map(Proxy) ->
    maps:get(server, Proxy);
proxy_server(Proxy) ->
    Proxy.

normalize_header_name(Name) when is_atom(Name) ->
    string:lowercase(atom_to_list(Name));
normalize_header_name(Name) when is_binary(Name) ->
    string:lowercase(binary_to_list(Name));
normalize_header_name(Name) when is_list(Name) ->
    string:lowercase(Name).

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
    atom_to_binary(Value, utf8);
to_binary(Value) when is_integer(Value) ->
    integer_to_binary(Value).
