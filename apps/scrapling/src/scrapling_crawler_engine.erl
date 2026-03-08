-module(scrapling_crawler_engine).

-export([crawl/2, crawl/3]).

crawl(SpiderModule, SessionManager) ->
    crawl(SpiderModule, SessionManager, #{}).

crawl(SpiderModule, SessionManager, Opts) when is_map(Opts) ->
    Scheduler0 = initial_scheduler(SpiderModule, Opts),
    AllowedDomains = allowed_domains(SpiderModule),
    loop(SpiderModule, SessionManager, Scheduler0, [], scrapling_crawl_stats:new(), AllowedDomains, Opts).

loop(SpiderModule, SessionManager0, Scheduler0, Items0, Stats0, AllowedDomains, Opts) ->
    case maybe_pause(Scheduler0, Items0, Stats0, Opts) of
        continue ->
            case scrapling_scheduler:dequeue(Scheduler0) of
                {empty, _Scheduler} ->
                    scrapling_crawl_result:new(lists:reverse(Items0), Stats0, true);
                {ok, Request, Scheduler1} ->
                    case is_domain_allowed(Request, AllowedDomains) of
                        false ->
                            loop(SpiderModule, SessionManager0, Scheduler1, Items0, Stats0, AllowedDomains, Opts);
                        true ->
                            case scrapling_session_manager:fetch(Request, SessionManager0) of
                                {ok, Response, SessionManager1} ->
                                    Stats1 = scrapling_crawl_stats:inc_requests(Stats0),
                                    notify_stats(Stats1, Opts),
                                    case maybe_handle_blocked_response(SpiderModule, Request, Response, Scheduler1, Stats1, Opts) of
                                        not_blocked ->
                                            Results = callback_results(SpiderModule, Request, Response),
                                            {Scheduler2, Items1, Stats2} = consume_results(Results, Scheduler1, Items0, Stats1, Opts),
                                            continue_or_pause(SpiderModule, SessionManager1, Scheduler2, Items1, Stats2, AllowedDomains, Opts);
                                        {blocked, Scheduler2, Stats2} ->
                                            continue_or_pause(SpiderModule, SessionManager1, Scheduler2, Items0, Stats2, AllowedDomains, Opts)
                                    end;
                                {error, _Error, SessionManager1} ->
                                    Stats1 = scrapling_crawl_stats:inc_failed(Stats0),
                                    notify_stats(Stats1, Opts),
                                    loop(SpiderModule, SessionManager1, Scheduler1, Items0, Stats1, AllowedDomains, Opts)
                            end
                    end
            end;
        {paused, Result} ->
            Result
    end.

continue_or_pause(SpiderModule, SessionManager, Scheduler, Items, Stats, AllowedDomains, Opts) ->
    case maybe_pause(Scheduler, Items, Stats, Opts) of
        continue ->
            loop(SpiderModule, SessionManager, Scheduler, Items, Stats, AllowedDomains, Opts);
        {paused, Result} ->
            Result
    end.

start_requests(SpiderModule) ->
    ensure_loaded(SpiderModule),
    case erlang:function_exported(SpiderModule, start_requests, 0) of
        true -> SpiderModule:start_requests();
        false ->
            case erlang:function_exported(SpiderModule, start_urls, 0) of
                true -> [scrapling_request:new(Url) || Url <- SpiderModule:start_urls()];
                false -> []
            end
    end.

allowed_domains(SpiderModule) ->
    ensure_loaded(SpiderModule),
    case erlang:function_exported(SpiderModule, allowed_domains, 0) of
        true -> [to_binary(Domain) || Domain <- SpiderModule:allowed_domains()];
        false -> []
    end.

is_domain_allowed(_Request, []) ->
    true;
is_domain_allowed(Request, AllowedDomains) ->
    Domain = scrapling_request:domain(Request),
    lists:any(fun(Allowed) -> Domain =:= Allowed orelse lists:suffix(binary_to_list(<<".", Allowed/binary>>), binary_to_list(Domain)) end,
              AllowedDomains).

maybe_handle_blocked_response(SpiderModule, Request, Response, Scheduler, Stats0, Opts) ->
    case is_blocked(SpiderModule, Response) of
        false ->
            not_blocked;
        true ->
            Stats1 = scrapling_crawl_stats:inc_blocked(Stats0),
            notify_stats(Stats1, Opts),
            case maps:get(retry_count, Request, 0) < max_blocked_retries(SpiderModule) of
                true ->
                    RetryRequest0 = prepare_retry_request(Request),
                    RetryRequest1 = retry_blocked_request(SpiderModule, RetryRequest0, Response),
                    {_Accepted, Scheduler1} = scrapling_scheduler:enqueue(RetryRequest1, Scheduler),
                    {blocked, Scheduler1, Stats1};
                false ->
                    {blocked, Scheduler, Stats1}
            end
    end.

is_blocked(SpiderModule, Response) ->
    ensure_loaded(SpiderModule),
    case erlang:function_exported(SpiderModule, is_blocked, 1) of
        true -> SpiderModule:is_blocked(Response);
        false -> lists:member(scrapling_response:status_code(Response), blocked_status_codes())
    end.

max_blocked_retries(SpiderModule) ->
    ensure_loaded(SpiderModule),
    case erlang:function_exported(SpiderModule, max_blocked_retries, 0) of
        true -> SpiderModule:max_blocked_retries();
        false -> 3
    end.

retry_blocked_request(SpiderModule, Request, Response) ->
    ensure_loaded(SpiderModule),
    case erlang:function_exported(SpiderModule, retry_blocked_request, 2) of
        true -> SpiderModule:retry_blocked_request(Request, Response);
        false -> Request
    end.

prepare_retry_request(Request) ->
    RetryRequest0 = scrapling_request:copy(Request),
    RetryCount = maps:get(retry_count, Request, 0) + 1,
    SessionOpts1 = maps:remove(proxy, maps:remove(proxies, scrapling_request:session_opts(RetryRequest0))),
    RetryRequest0#{priority => scrapling_request:priority(Request) - 1,
                   dont_filter => true,
                   retry_count => RetryCount,
                   session_opts => SessionOpts1}.

blocked_status_codes() ->
    [401, 403, 407, 429, 444, 500, 502, 503, 504].

callback_results(SpiderModule, Request, Response) ->
    case scrapling_request:callback(Request) of
        undefined -> normalize_results(SpiderModule:parse(Response));
        Callback when is_function(Callback, 1) -> normalize_results(Callback(Response));
        Callback when is_atom(Callback) -> normalize_results(apply(SpiderModule, Callback, [Response]));
        {Module, Callback} -> normalize_results(apply(Module, Callback, [Response]))
    end.

normalize_results(undefined) -> [];
normalize_results(Results) when is_list(Results) -> Results;
normalize_results(Result) -> [Result].

consume_results([], Scheduler, Items, Stats, _Opts) ->
    {Scheduler, Items, Stats};
consume_results([undefined | Rest], Scheduler, Items, Stats, Opts) ->
    consume_results(Rest, Scheduler, Items, Stats, Opts);
consume_results([Result | Rest], Scheduler0, Items0, Stats0, Opts) ->
    case scrapling_request:is_request(Result) of
        true ->
            {_Accepted, Scheduler1} = scrapling_scheduler:enqueue(Result, Scheduler0),
            consume_results(Rest, Scheduler1, Items0, Stats0, Opts);
        false ->
            Stats1 = scrapling_crawl_stats:inc_items(Stats0),
            notify_item(Result, Stats1, Opts),
            notify_stats(Stats1, Opts),
            consume_results(Rest, Scheduler0, [Result | Items0], Stats1, Opts)
    end.

enqueue_all([], Scheduler) ->
    Scheduler;
enqueue_all([Request | Rest], Scheduler0) ->
    {_Accepted, Scheduler1} = scrapling_scheduler:enqueue(Request, Scheduler0),
    enqueue_all(Rest, Scheduler1).

initial_scheduler(SpiderModule, Opts) ->
    case maps:get(checkpoint_data, Opts, undefined) of
        undefined ->
            Requests = start_requests(SpiderModule),
            enqueue_all(Requests, scrapling_scheduler:new());
        CheckpointData ->
            scrapling_scheduler:restore(CheckpointData)
    end.

maybe_pause(Scheduler, Items, Stats, Opts) ->
    case should_pause(Stats, Opts) of
        true ->
            pause_result(Scheduler, Items, Stats, Opts);
        false ->
            continue
    end.

should_pause(Stats, Opts) ->
    pause_after_requests_requested(Stats, Opts) orelse external_pause_requested().

pause_after_requests_requested(Stats, Opts) ->
    RequestsCount = scrapling_crawl_stats:requests_count(Stats),
    case maps:get(pause_after_requests, Opts, undefined) of
        Limit when is_integer(Limit), Limit > 0 -> RequestsCount >= Limit;
        _ -> false
    end.

external_pause_requested() ->
    consume_pause_requests(0) > 0.

consume_pause_requests(Count) ->
    receive
        {scrapling_pause, request} ->
            consume_pause_requests(Count + 1)
    after 0 ->
        Count
    end.

pause_result(Scheduler, Items, Stats, Opts) ->
    case maps:get(checkpoint_manager, Opts, undefined) of
        CheckpointManager when is_map(CheckpointManager) ->
            maybe_save_checkpoint(Scheduler, Opts),
            {paused, scrapling_crawl_result:new(lists:reverse(Items), Stats, false)};
        _ ->
            {paused, scrapling_crawl_result:new(lists:reverse(Items), Stats, true)}
    end.

maybe_save_checkpoint(Scheduler, Opts) ->
    case maps:get(checkpoint_manager, Opts, undefined) of
        CheckpointManager when is_map(CheckpointManager) ->
            scrapling_checkpoint:save(CheckpointManager, scrapling_scheduler:snapshot(Scheduler));
        _ ->
            ok
    end.

notify_item(Item, Stats, Opts) ->
    case maps:get(on_item, Opts, undefined) of
        Hook when is_function(Hook, 2) ->
            safe_invoke(fun() -> Hook(Item, Stats) end);
        _ ->
            ok
    end.

notify_stats(Stats, Opts) ->
    case maps:get(on_stats, Opts, undefined) of
        Hook when is_function(Hook, 1) ->
            safe_invoke(fun() -> Hook(Stats) end);
        _ ->
            ok
    end.

safe_invoke(Fun) ->
    try
        Fun(),
        ok
    catch
        _:_ -> ok
    end.

ensure_loaded(Module) ->
    case code:ensure_loaded(Module) of
        {module, Module} -> ok;
        _ -> erlang:error({module_not_loaded, Module})
    end.

to_binary(Value) when is_binary(Value) ->
    Value;
to_binary(Value) when is_list(Value) ->
    unicode:characters_to_binary(Value);
to_binary(Value) when is_atom(Value) ->
    atom_to_binary(Value, utf8).
