-module(scrapling_spider).

-export([start/1, start/2, stream/1, stream/2, next/1, next/2, stats/1]).

start(SpiderModule) ->
    start(SpiderModule, #{}).

start(SpiderModule, Opts) when is_map(Opts) ->
    run(SpiderModule, Opts).

stream(SpiderModule) ->
    stream(SpiderModule, #{}).

stream(SpiderModule, Opts) when is_map(Opts) ->
    StreamPid = spawn(fun() -> stream_controller(SpiderModule, Opts) end),
    {ok, StreamPid}.

next(StreamPid) ->
    next(StreamPid, 5000).

next(StreamPid, Timeout) when is_pid(StreamPid), is_integer(Timeout), Timeout >= 0 ->
    call(StreamPid, next, Timeout).

stats(StreamPid) when is_pid(StreamPid) ->
    call(StreamPid, stats, 5000).

run(SpiderModule, Opts) ->
    ensure_loaded(SpiderModule),
    SessionManager0 = maps:get(session_manager, Opts, scrapling_session_manager:new()),
    SessionManager1 = maybe_configure_sessions(SpiderModule, SessionManager0),
    CheckpointData = maybe_load_checkpoint(Opts),
    EngineOpts = maps:merge(runtime_opts(Opts), checkpoint_opts(CheckpointData)),
    Result = scrapling_crawler_engine:crawl(SpiderModule, SessionManager1, EngineOpts),
    maybe_cleanup_checkpoint(Opts, Result),
    Result.

stream_controller(SpiderModule, Opts) ->
    ControllerPid = self(),
    {WorkerPid, MonitorRef} = spawn_monitor(fun() -> stream_worker(ControllerPid, SpiderModule, Opts) end),
    InitialState = #{items => queue:new(),
                     waiters => queue:new(),
                     stats => scrapling_crawl_stats:new(),
                     status => running,
                     error => undefined,
                     worker_pid => WorkerPid,
                     monitor_ref => MonitorRef},
    stream_loop(InitialState).

stream_worker(ControllerPid, SpiderModule, Opts) ->
    HookedOpts = Opts#{on_item => fun(Item, StreamStats) ->
                                     ControllerPid ! {stream_item, Item, StreamStats},
                                     ok
                                 end,
                      on_stats => fun(StreamStats) ->
                                      ControllerPid ! {stream_stats, StreamStats},
                                      ok
                                  end},
    try
        Result = run(SpiderModule, HookedOpts),
        ControllerPid ! {stream_done, Result}
    catch
        Class:Reason:Stacktrace ->
            ControllerPid ! {stream_error, {Class, Reason, Stacktrace}}
    end.

stream_loop(State0) ->
    receive
        {call, From, next} ->
            State1 = handle_next_call(From, State0),
            stream_loop(State1);
        {call, From, stats} ->
            reply(From, maps:get(stats, State0)),
            stream_loop(State0);
        {stream_item, Item, StreamStats} ->
            State1 = handle_stream_item(Item, StreamStats, State0),
            stream_loop(State1);
        {stream_stats, StreamStats} ->
            stream_loop(State0#{stats => StreamStats});
        {stream_done, Result} ->
            State1 = flush_waiters_if_terminal(
                         State0#{status => done,
                                 stats => scrapling_crawl_result:stats(Result),
                                 result => Result}),
            stream_loop(State1);
        {stream_error, Error} ->
            State1 = flush_waiters_if_terminal(State0#{status => error, error => Error}),
            stream_loop(State1);
        {'DOWN', MonitorRef, process, WorkerPid, Reason} ->
            State1 = handle_worker_down(MonitorRef, WorkerPid, Reason, State0),
            stream_loop(State1)
    end.

handle_next_call(From, State0) ->
    Items0 = maps:get(items, State0),
    case queue:out(Items0) of
        {{value, Item}, Items1} ->
            reply(From, {ok, Item}),
            flush_waiters_if_terminal(State0#{items => Items1});
        {empty, _} ->
            case {maps:get(status, State0), maps:get(error, State0, undefined)} of
                {done, _} ->
                    reply(From, done),
                    State0;
                {error, Error} ->
                    reply(From, {error, Error}),
                    State0;
                _ ->
                    Waiters0 = maps:get(waiters, State0),
                    State0#{waiters => queue:in(From, Waiters0)}
            end
    end.

handle_stream_item(Item, StreamStats, State0) ->
    Waiters0 = maps:get(waiters, State0),
    State1 = State0#{stats => StreamStats},
    case queue:out(Waiters0) of
        {{value, From}, Waiters1} ->
            reply(From, {ok, Item}),
            State1#{waiters => Waiters1};
        {empty, _} ->
            Items0 = maps:get(items, State1),
            State1#{items => queue:in(Item, Items0)}
    end.

handle_worker_down(MonitorRef, WorkerPid, Reason, State0) ->
    case {maps:get(monitor_ref, State0), maps:get(worker_pid, State0), maps:get(status, State0), Reason} of
        {MonitorRef, WorkerPid, running, normal} ->
            flush_waiters_if_terminal(State0#{status => done});
        {MonitorRef, WorkerPid, running, _} ->
            flush_waiters_if_terminal(State0#{status => error, error => {worker_down, Reason}});
        _ ->
            State0
    end.

flush_waiters_if_terminal(State0) ->
    case {queue:is_empty(maps:get(items, State0)), maps:get(status, State0), maps:get(error, State0, undefined)} of
        {true, done, _} ->
            flush_waiters(State0, done);
        {true, error, Error} ->
            flush_waiters(State0, {error, Error});
        _ ->
            State0
    end.

flush_waiters(State0, Reply) ->
    flush_waiter_queue(maps:get(waiters, State0), Reply),
    State0#{waiters => queue:new()}.

flush_waiter_queue(Waiters0, Reply) ->
    case queue:out(Waiters0) of
        {{value, From}, Waiters1} ->
            reply(From, Reply),
            flush_waiter_queue(Waiters1, Reply);
        {empty, _} ->
            ok
    end.

call(StreamPid, Request, Timeout) ->
    Ref = make_ref(),
    StreamPid ! {call, {self(), Ref}, Request},
    receive
        {Ref, Reply} -> Reply
    after Timeout ->
        {error, timeout}
    end.

reply({Pid, Ref}, Reply) ->
    Pid ! {Ref, Reply},
    ok.

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
    maps:with([checkpoint_manager, pause_after_requests, on_item, on_stats], Opts).

maybe_cleanup_checkpoint(Opts, Result) ->
    case {maps:get(checkpoint_manager, Opts, undefined), scrapling_crawl_result:completed(Result)} of
        {CheckpointManager, true} when is_map(CheckpointManager) ->
            scrapling_checkpoint:cleanup(CheckpointManager);
        _ ->
            ok
    end.
