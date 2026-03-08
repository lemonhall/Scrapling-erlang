-module(scrapling_spider).

-export([start/1, start/2]).

start(SpiderModule) ->
    start(SpiderModule, #{}).

start(SpiderModule, Opts) when is_map(Opts) ->
    ensure_loaded(SpiderModule),
    SessionManager0 = maps:get(session_manager, Opts, scrapling_session_manager:new()),
    SessionManager1 = maybe_configure_sessions(SpiderModule, SessionManager0),
    CheckpointData = maybe_load_checkpoint(Opts),
    EngineOpts = maps:merge(runtime_opts(Opts), checkpoint_opts(CheckpointData)),
    Result = scrapling_crawler_engine:crawl(SpiderModule, SessionManager1, EngineOpts),
    maybe_cleanup_checkpoint(Opts, Result),
    Result.

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

maybe_load_checkpoint(Opts) ->
    case {maps:get(resume, Opts, false), maps:get(checkpoint_manager, Opts, undefined)} of
        {true, CheckpointManager} when is_map(CheckpointManager) ->
            case scrapling_checkpoint:load(CheckpointManager) of
                {ok, CheckpointData} -> CheckpointData;
                _ -> undefined
            end;
        _ ->
            undefined
    end.

checkpoint_opts(undefined) ->
    #{};
checkpoint_opts(CheckpointData) ->
    #{checkpoint_data => CheckpointData}.

runtime_opts(Opts) ->
    maps:with([checkpoint_manager, pause_after_requests], Opts).

maybe_cleanup_checkpoint(Opts, Result) ->
    case {maps:get(checkpoint_manager, Opts, undefined), scrapling_crawl_result:completed(Result)} of
        {CheckpointManager, true} when is_map(CheckpointManager) ->
            scrapling_checkpoint:cleanup(CheckpointManager);
        _ ->
            ok
    end.
