-module(scrapling_spider).

-export([start/1, start/2]).

start(SpiderModule) ->
    start(SpiderModule, #{}).

start(SpiderModule, Opts) when is_map(Opts) ->
    ensure_loaded(SpiderModule),
    SessionManager0 = maps:get(session_manager, Opts, scrapling_session_manager:new()),
    SessionManager1 = maybe_configure_sessions(SpiderModule, SessionManager0),
    scrapling_crawler_engine:crawl(SpiderModule, SessionManager1).

maybe_configure_sessions(SpiderModule, SessionManager) ->
    case erlang:function_exported(SpiderModule, configure_sessions, 1) of
        true ->
            case SpiderModule:configure_sessions(SessionManager) of
                {ok, Updated} -> Updated;
                Updated when is_map(Updated) -> Updated
            end;
        false -> SessionManager
    end.

ensure_loaded(Module) ->
    case code:ensure_loaded(Module) of
        {module, Module} -> ok;
        _ -> erlang:error({module_not_loaded, Module})
    end.
