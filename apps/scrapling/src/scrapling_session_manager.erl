-module(scrapling_session_manager).

-export([
    new/0,
    custom/1,
    static_session/1,
    dynamic_session/1,
    stealth_session/1,
    add/3,
    add/4,
    len/1,
    session_ids/1,
    default_session_id/1,
    get/2,
    fetch/2
]).

new() ->
    #{sessions => #{}, order => [], default_session_id => undefined}.

custom(Fun) when is_function(Fun, 1) ->
    #{type => custom, fetch => Fun}.

static_session(Pid) when is_pid(Pid) ->
    #{type => static, ref => Pid}.

dynamic_session(Pid) when is_pid(Pid) ->
    #{type => dynamic, ref => Pid}.

stealth_session(Pid) when is_pid(Pid) ->
    #{type => stealth, ref => Pid}.

add(SessionId, Session, Manager) ->
    add(SessionId, Session, #{}, Manager).

add(SessionId, Session, Opts, Manager0) when is_map(Opts), is_map(Manager0) ->
    SessionKey = to_binary(SessionId),
    Sessions0 = maps:get(sessions, Manager0, #{}),
    case maps:is_key(SessionKey, Sessions0) of
        true ->
            {error, #{type => <<"duplicate_session_id">>, session_id => SessionKey}};
        false ->
            Sessions1 = Sessions0#{SessionKey => Session},
            Order0 = maps:get(order, Manager0, []),
            Default0 = maps:get(default_session_id, Manager0, undefined),
            Default1 = case {maps:get(default, Opts, undefined), Default0} of
                {false, _} -> Default0;
                {true, _} -> SessionKey;
                {undefined, undefined} -> SessionKey;
                _ -> Default0
            end,
            {ok, Manager0#{sessions => Sessions1, order => Order0 ++ [SessionKey], default_session_id => Default1}}
    end.

len(Manager) ->
    length(maps:get(order, Manager, [])).

session_ids(Manager) ->
    maps:get(order, Manager, []).

default_session_id(Manager) ->
    case maps:get(default_session_id, Manager, undefined) of
        undefined -> {error, #{type => <<"no_sessions_registered">>}};
        SessionId -> {ok, SessionId}
    end.

get(SessionId, Manager) ->
    SessionKey = to_binary(SessionId),
    Sessions = maps:get(sessions, Manager, #{}),
    case maps:get(SessionKey, Sessions, undefined) of
        undefined -> {error, #{type => <<"session_not_found">>, session_id => SessionKey, available => session_ids(Manager)}};
        Session -> {ok, Session}
    end.

fetch(Request, Manager) ->
    case resolve_session_id(Request, Manager) of
        {error, Error} -> {error, Error, Manager};
        {ok, SessionId} ->
            case get(SessionId, Manager) of
                {ok, Session} -> dispatch_fetch(Request, Session, Manager);
                {error, Error} -> {error, Error, Manager}
            end
    end.

resolve_session_id(Request, Manager) ->
    case scrapling_request:sid(Request) of
        <<>> -> default_session_id(Manager);
        SessionId -> {ok, SessionId}
    end.

dispatch_fetch(Request, #{type := custom, fetch := Fun}, Manager) ->
    case normalize_fetch_result(Fun(Request), Request) of
        {ok, Response} -> {ok, Response, Manager};
        {error, Error} -> {error, Error, Manager}
    end;
dispatch_fetch(Request, #{type := static, ref := Pid}, Manager) ->
    SessionOpts = scrapling_request:session_opts(Request),
    Method = maps:get(method, SessionOpts, get),
    Opts = maps:remove(method, SessionOpts),
    Response = scrapling_fetcher_session:request(Pid, Method, binary_to_list(scrapling_request:url(Request)), Opts),
    {ok, attach_request_meta(Response, Request), Manager};
dispatch_fetch(Request, #{type := dynamic, ref := Pid}, Manager) ->
    SessionOpts = scrapling_request:session_opts(Request),
    Response = scrapling_dynamic_session:fetch(Pid, binary_to_list(scrapling_request:url(Request)), SessionOpts),
    normalize_runtime_fetch_result(Response, Request, Manager);
dispatch_fetch(Request, #{type := stealth, ref := Pid}, Manager) ->
    SessionOpts = scrapling_request:session_opts(Request),
    Response = scrapling_stealth_session:fetch(Pid, binary_to_list(scrapling_request:url(Request)), SessionOpts),
    normalize_runtime_fetch_result(Response, Request, Manager).

normalize_runtime_fetch_result({error, Error}, _Request, Manager) ->
    {error, Error, Manager};
normalize_runtime_fetch_result(Response, Request, Manager) ->
    {ok, attach_request_meta(Response, Request), Manager}.

normalize_fetch_result({ok, Response}, Request) ->
    {ok, attach_request_meta(Response, Request)};
normalize_fetch_result({error, Error}, _Request) ->
    {error, Error};
normalize_fetch_result(Response, Request) when is_map(Response) ->
    {ok, attach_request_meta(Response, Request)}.

attach_request_meta(Response, Request) ->
    Meta0 = scrapling_response:meta(Response),
    Response#{request => Request, meta => maps:merge(scrapling_request:meta(Request), Meta0)}.

to_binary(Value) when is_binary(Value) ->
    Value;
to_binary(Value) when is_list(Value) ->
    unicode:characters_to_binary(Value);
to_binary(Value) when is_atom(Value) ->
    atom_to_binary(Value, utf8).
