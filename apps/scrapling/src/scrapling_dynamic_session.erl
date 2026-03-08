-module(scrapling_dynamic_session).

-behaviour(gen_server).

-export([start_link/0, start_link/1, stop/1, fetch/2, fetch/3]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

start_link() ->
    start_link(#{}).

start_link(Opts) when is_map(Opts) ->
    gen_server:start_link(?MODULE, Opts, []).

stop(Session) ->
    gen_server:call(Session, stop, infinity).

fetch(Session, Url) ->
    fetch(Session, Url, #{}).

fetch(Session, Url, Opts) when is_map(Opts) ->
    gen_server:call(Session, {fetch, Url, Opts}, infinity).

init(Opts) ->
    {ok, #{defaults => Opts}}.

handle_call(stop, _From, State) ->
    {stop, normal, ok, State};
handle_call({fetch, Url, Opts}, _From, State) ->
    Defaults = maps:get(defaults, State, #{}),
    Response = scrapling_dynamic_fetcher:fetch(Url, maps:merge(Defaults, Opts)),
    {reply, Response, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
