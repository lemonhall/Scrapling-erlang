-module(scrapling_crawler_engine).

-export([crawl/2, crawl/3]).

crawl(SpiderModule, SessionManager) ->
    crawl(SpiderModule, SessionManager, #{}).

crawl(SpiderModule, SessionManager, Opts) when is_map(Opts) ->
    Scheduler0 = initial_scheduler(SpiderModule, Opts),
    AllowedDomains = allowed_domains(SpiderModule),
    loop(SpiderModule, SessionManager, Scheduler0, [], scrapling_crawl_stats:new(), AllowedDomains).

loop(SpiderModule, SessionManager0, Scheduler0, Items0, Stats0, AllowedDomains) ->
    case scrapling_scheduler:dequeue(Scheduler0) of
        {empty, _Scheduler} ->
            scrapling_crawl_result:new(lists:reverse(Items0), Stats0, true);
        {ok, Request, Scheduler1} ->
            case is_domain_allowed(Request, AllowedDomains) of
                false ->
                    loop(SpiderModule, SessionManager0, Scheduler1, Items0, Stats0, AllowedDomains);
                true ->
                    case scrapling_session_manager:fetch(Request, SessionManager0) of
                        {ok, Response, SessionManager1} ->
                            Stats1 = scrapling_crawl_stats:inc_requests(Stats0),
                            Results = callback_results(SpiderModule, Request, Response),
                            {Scheduler2, Items1, Stats2} = consume_results(Results, Scheduler1, Items0, Stats1),
                            loop(SpiderModule, SessionManager1, Scheduler2, Items1, Stats2, AllowedDomains);
                        {error, _Error, SessionManager1} ->
                            loop(SpiderModule, SessionManager1, Scheduler1, Items0, scrapling_crawl_stats:inc_failed(Stats0), AllowedDomains)
                    end
            end
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

consume_results([], Scheduler, Items, Stats) ->
    {Scheduler, Items, Stats};
consume_results([undefined | Rest], Scheduler, Items, Stats) ->
    consume_results(Rest, Scheduler, Items, Stats);
consume_results([Result | Rest], Scheduler0, Items0, Stats0) ->
    case scrapling_request:is_request(Result) of
        true ->
            {_Accepted, Scheduler1} = scrapling_scheduler:enqueue(Result, Scheduler0),
            consume_results(Rest, Scheduler1, Items0, Stats0);
        false ->
            consume_results(Rest, Scheduler0, [Result | Items0], scrapling_crawl_stats:inc_items(Stats0))
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
