-module(scrapling_fetcher_session).

-behaviour(gen_server).

-export([
    start_link/0,
    start_link/1,
    stop/1,
    get/2,
    get/3,
    post/3,
    post/4,
    put/3,
    put/4,
    delete/2,
    delete/3,
    delete/4,
    request/3,
    request/4
]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

start_link() ->
    start_link(#{}).

start_link(Opts) when is_map(Opts) ->
    gen_server:start_link(?MODULE, Opts, []).

stop(Session) ->
    gen_server:call(Session, stop, infinity).

get(Session, Url) ->
    request(Session, get, Url, #{}).

get(Session, Url, Opts) ->
    request(Session, get, Url, Opts).

post(Session, Url, Body) ->
    request(Session, post, Url, #{body => Body}).

post(Session, Url, Body, Opts) when is_map(Opts) ->
    request(Session, post, Url, Opts#{body => Body}).

put(Session, Url, Body) ->
    request(Session, put, Url, #{body => Body}).

put(Session, Url, Body, Opts) when is_map(Opts) ->
    request(Session, put, Url, Opts#{body => Body}).

delete(Session, Url) ->
    request(Session, delete, Url, #{}).

delete(Session, Url, Opts) when is_map(Opts) ->
    request(Session, delete, Url, Opts);
delete(Session, Url, Body) ->
    request(Session, delete, Url, #{body => Body}).

delete(Session, Url, Body, Opts) when is_map(Opts) ->
    request(Session, delete, Url, Opts#{body => Body}).

request(Session, Method, Url) ->
    request(Session, Method, Url, #{}).

request(Session, Method, Url, Opts) when is_map(Opts) ->
    gen_server:call(Session, {request, Method, Url, Opts}, infinity).

init(Opts) ->
    {ok, Profile} = httpc:start_standalone([{profile, scrapling_session}]),
    State = normalize_state(Opts),
    {ok, State#{profile => Profile}}.

handle_call(stop, _From, State) ->
    {stop, normal, ok, State};
handle_call({request, Method, Url, Opts}, _From, State0) ->
    {RequestOpts, State1} = prepare_request_opts(Opts, State0),
    Response = scrapling_fetcher:request(Method, Url, RequestOpts),
    State2 = update_cookies(Response, State1),
    {reply, Response, State2}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, State) ->
    case httpc:stop_service(maps:get(profile, State)) of
        ok -> ok;
        {error, no_such_service} -> ok
    end.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

normalize_state(Opts) ->
    #{headers => headers_to_map(maps:get(headers, Opts, [])),
      cookies => cookies_to_map(maps:get(cookies, Opts, #{})),
      proxy => maps:get(proxy, Opts, undefined),
      proxy_rotator => maps:get(proxy_rotator, Opts, undefined)}.

prepare_request_opts(Opts, State0) ->
    StateHeaders = maps:get(headers, State0),
    RequestHeaders = headers_to_map(maps:get(headers, Opts, [])),
    Headers = maps:merge(StateHeaders, RequestHeaders),
    StateCookies = maps:get(cookies, State0),
    RequestCookies = cookies_to_map(maps:get(cookies, Opts, #{})),
    Cookies = maps:merge(StateCookies, RequestCookies),
    {Proxy, State1} = select_proxy(Opts, State0),
    Meta0 = maps:get(meta, Opts, #{}),
    Meta = add_proxy_meta(Meta0, Proxy),
    RequestOpts0 = maps:without([headers, cookies, meta], Opts),
    Profile = maps:get(profile, State0),
    RequestOpts1 = RequestOpts0#{headers => maps:to_list(Headers), cookies => Cookies, meta => Meta, profile => Profile},
    RequestOpts2 = case Proxy of
        undefined -> maps:remove(proxy, RequestOpts1);
        _ -> RequestOpts1#{proxy => Proxy}
    end,
    {RequestOpts2, State1}.

select_proxy(Opts, State) ->
    case maps:get(proxy, Opts, undefined) of
        undefined ->
            case maps:get(proxy_rotator, State, undefined) of
                undefined -> {maps:get(proxy, State, undefined), State};
                Rotator ->
                    {Proxy, NextRotator} = scrapling_proxy_rotator:next(Rotator),
                    {Proxy, State#{proxy_rotator => NextRotator}}
            end;
        Proxy ->
            {Proxy, State}
    end.

add_proxy_meta(Meta, undefined) ->
    Meta;
add_proxy_meta(Meta, Proxy) ->
    Meta#{proxy => proxy_value(Proxy)}.

proxy_value(Proxy) when is_map(Proxy) ->
    maps:get(server, Proxy);
proxy_value(Proxy) ->
    Proxy.

update_cookies(Response, State) ->
    Cookies = maps:merge(maps:get(cookies, State), scrapling_response:cookies(Response)),
    State#{cookies => Cookies}.

headers_to_map(Headers) when is_map(Headers) ->
    maps:from_list([{normalize_name(Name), to_list(Value)} || {Name, Value} <- maps:to_list(Headers)]);
headers_to_map(Headers) when is_list(Headers) ->
    maps:from_list([{normalize_name(Name), to_list(Value)} || {Name, Value} <- Headers]).

cookies_to_map(Cookies) when is_map(Cookies) ->
    #{to_list(Name) => to_list(Value) || Name := Value <- Cookies};
cookies_to_map(Cookies) when is_list(Cookies) ->
    maps:from_list([{to_list(Name), to_list(Value)} || {Name, Value} <- Cookies]);
cookies_to_map(undefined) ->
    #{}.

normalize_name(Name) when is_atom(Name) ->
    string:lowercase(atom_to_list(Name));
normalize_name(Name) when is_binary(Name) ->
    string:lowercase(binary_to_list(Name));
normalize_name(Name) when is_list(Name) ->
    string:lowercase(Name).

to_list(Value) when is_list(Value) ->
    Value;
to_list(Value) when is_binary(Value) ->
    binary_to_list(Value);
to_list(Value) when is_atom(Value) ->
    atom_to_list(Value);
to_list(Value) when is_integer(Value) ->
    integer_to_list(Value).
