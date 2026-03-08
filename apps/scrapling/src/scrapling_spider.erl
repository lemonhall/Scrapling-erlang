-module(scrapling_spider).

-export([
    start/1,
    start/2,
    run/1,
    run/2,
    stream/1,
    stream/2,
    next/1,
    next/2,
    stats/1,
    pause/1,
    await/1,
    await/2
]).

start(SpiderModule) ->
    start(SpiderModule, #{}).

start(SpiderModule, Opts) when is_map(Opts) ->
    execute(SpiderModule, Opts).

run(SpiderModule) ->
    run(SpiderModule, #{}).

run(SpiderModule, Opts) when is_map(Opts) ->
    {ok, spawn_controller(SpiderModule, Opts)}.

stream(SpiderModule) ->
    stream(SpiderModule, #{}).

stream(SpiderModule, Opts) when is_map(Opts) ->
    {ok, spawn_controller(SpiderModule, Opts)}.

next(StreamPid) ->
    next(StreamPid, 5000).

next(StreamPid, Timeout) when is_pid(StreamPid), is_integer(Timeout), Timeout >= 0 ->
    call(StreamPid, next, Timeout).

stats(StreamPid) when is_pid(StreamPid) ->
    call(StreamPid, stats, 5000).

pause(RunnerPid) when is_pid(RunnerPid) ->
    call(RunnerPid, pause, 5000).

await(RunnerPid) ->
    await(RunnerPid, 5000).

await(RunnerPid, Timeout) when is_pid(RunnerPid), is_integer(Timeout), Timeout >= 0 ->
    call(RunnerPid, await, Timeout).

spawn_controller(SpiderModule, Opts) ->
    spawn(fun() -> controller(SpiderModule, Opts) end).

execute(SpiderModule, Opts) ->
    ensure_loaded(SpiderModule),
    SessionManager0 = maps:get(session_manager, Opts, scrapling_session_manager:new()),
    SessionManager1 = maybe_configure_sessions(SpiderModule, SessionManager0),
    CheckpointData = maybe_load_checkpoint(Opts),
    EngineOpts = maps:merge(runtime_opts(Opts), checkpoint_opts(CheckpointData)),
    Result = scrapling_crawler_engine:crawl(SpiderModule, SessionManager1, EngineOpts),
    maybe_cleanup_checkpoint(Opts, Result),
    Result.

controller(SpiderModule, Opts) ->
    ControllerPid = self(),
    {WorkerPid, MonitorRef} = spawn_monitor(fun() -> worker(ControllerPid, SpiderModule, Opts) end),
    InitialState = #{items => queue:new(),
                     item_waiters => queue:new(),
                     awaiters => queue:new(),
                     stats => scrapling_crawl_stats:new(),
                     status => running,
                     error => undefined,
                     result => undefined,
                     worker_pid => WorkerPid,
                     monitor_ref => MonitorRef},
    controller_loop(InitialState).

worker(ControllerPid, SpiderModule, Opts) ->
    HookedOpts = Opts#{on_item => fun(Item, StreamStats) ->
                                     ControllerPid ! {spider_item, Item, StreamStats},
                                     ok
                                 end,
                      on_stats => fun(StreamStats) ->
                                      ControllerPid ! {spider_stats, StreamStats},
                                      ok
                                  end},
    try
        Result = execute(SpiderModule, HookedOpts),
        ControllerPid ! {spider_done, Result}
    catch
        Class:Reason:Stacktrace ->
            ControllerPid ! {spider_error, {Class, Reason, Stacktrace}}
    end.

controller_loop(State0) ->
    receive
        {call, From, next} ->
            controller_loop(handle_next_call(From, State0));
        {call, From, stats} ->
            reply(From, maps:get(stats, State0)),
            controller_loop(State0);
        {call, From, await} ->
            controller_loop(handle_await_call(From, State0));
        {call, From, pause} ->
            controller_loop(handle_pause_call(From, State0));
        {spider_item, Item, StreamStats} ->
            controller_loop(handle_item(Item, StreamStats, State0));
        {spider_stats, StreamStats} ->
            controller_loop(State0#{stats => StreamStats});
        {spider_done, Result} ->
            State1 = State0#{status => done,
                             stats => scrapling_crawl_result:stats(Result),
                             result => Result},
            State2 = flush_awaiters(State1, Result),
            controller_loop(flush_item_waiters_if_terminal(State2));
        {spider_error, Error} ->
            State1 = State0#{status => error, error => Error},
            State2 = flush_awaiters(State1, {error, Error}),
            controller_loop(flush_item_waiters_if_terminal(State2));
        {'DOWN', MonitorRef, process, WorkerPid, Reason} ->
            controller_loop(handle_worker_down(MonitorRef, WorkerPid, Reason, State0))
    end.

handle_next_call(From, State0) ->
    Items0 = maps:get(items, State0),
    case queue:out(Items0) of
        {{value, Item}, Items1} ->
            reply(From, {ok, Item}),
            flush_item_waiters_if_terminal(State0#{items => Items1});
        {empty, _} ->
            case {maps:get(status, State0), maps:get(error, State0, undefined)} of
                {done, _} ->
                    reply(From, done),
                    State0;
                {error, Error} ->
                    reply(From, {error, Error}),
                    State0;
                _ ->
                    ItemWaiters0 = maps:get(item_waiters, State0),
                    State0#{item_waiters => queue:in(From, ItemWaiters0)}
            end
    end.

handle_await_call(From, State0) ->
    case {maps:get(status, State0), maps:get(result, State0, undefined), maps:get(error, State0, undefined)} of
        {done, Result, _} when Result =/= undefined ->
            reply(From, Result),
            State0;
        {error, _, Error} ->
            reply(From, {error, Error}),
            State0;
        _ ->
            Awaiters0 = maps:get(awaiters, State0),
            State0#{awaiters => queue:in(From, Awaiters0)}
    end.

handle_pause_call(From, State0) ->
    case maps:get(status, State0) of
        running ->
            maps:get(worker_pid, State0) ! {scrapling_pause, request},
            reply(From, ok),
            State0;
        _ ->
            reply(From, {error, no_active_crawl}),
            State0
    end.

handle_item(Item, StreamStats, State0) ->
    ItemWaiters0 = maps:get(item_waiters, State0),
    State1 = State0#{stats => StreamStats},
    case queue:out(ItemWaiters0) of
        {{value, From}, ItemWaiters1} ->
            reply(From, {ok, Item}),
            State1#{item_waiters => ItemWaiters1};
        {empty, _} ->
            Items0 = maps:get(items, State1),
            State1#{items => queue:in(Item, Items0)}
    end.

handle_worker_down(MonitorRef, WorkerPid, Reason, State0) ->
    case {maps:get(monitor_ref, State0), maps:get(worker_pid, State0), maps:get(status, State0)} of
        {MonitorRef, WorkerPid, running} ->
            Error = {worker_down, Reason},
            State1 = State0#{status => error, error => Error},
            State2 = flush_awaiters(State1, {error, Error}),
            flush_item_waiters_if_terminal(State2);
        _ ->
            State0
    end.

flush_item_waiters_if_terminal(State0) ->
    case {queue:is_empty(maps:get(items, State0)), maps:get(status, State0), maps:get(error, State0, undefined)} of
        {true, done, _} ->
            flush_item_waiters(State0, done);
        {true, error, Error} ->
            flush_item_waiters(State0, {error, Error});
        _ ->
            State0
    end.

flush_item_waiters(State0, Reply) ->
    flush_queue(maps:get(item_waiters, State0), Reply),
    State0#{item_waiters => queue:new()}.

flush_awaiters(State0, Reply) ->
    flush_queue(maps:get(awaiters, State0), Reply),
    State0#{awaiters => queue:new()}.

flush_queue(Waiters0, Reply) ->
    case queue:out(Waiters0) of
        {{value, From}, Waiters1} ->
            reply(From, Reply),
            flush_queue(Waiters1, Reply);
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
