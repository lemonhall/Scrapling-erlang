-module(scrapling_scheduler).

-export([new/0, enqueue/2, dequeue/1, len/1, is_empty/1, snapshot/1, restore/1]).

new() ->
    #{pending => [], seen => sets:new([{version, 2}]), next_seq => 0}.

enqueue(Request, Scheduler0) ->
    Fingerprint = scrapling_request:fingerprint(Request),
    Seen0 = maps:get(seen, Scheduler0),
    DontFilter = scrapling_request:dont_filter(Request),
    case (not DontFilter) andalso sets:is_element(Fingerprint, Seen0) of
        true ->
            {false, Scheduler0};
        false ->
            Seq = maps:get(next_seq, Scheduler0, 0),
            Item = {-scrapling_request:priority(Request), Seq, Request},
            Pending0 = maps:get(pending, Scheduler0, []),
            Pending1 = lists:sort(Pending0 ++ [Item]),
            Seen1 = case DontFilter of
                true -> Seen0;
                false -> sets:add_element(Fingerprint, Seen0)
            end,
            {true, Scheduler0#{pending => Pending1, seen => Seen1, next_seq => Seq + 1}}
    end.

dequeue(Scheduler0) ->
    case maps:get(pending, Scheduler0, []) of
        [] -> {empty, Scheduler0};
        [{_Priority, _Seq, Request} | Rest] -> {ok, Request, Scheduler0#{pending => Rest}}
    end.

len(Scheduler) ->
    length(maps:get(pending, Scheduler, [])).

is_empty(Scheduler) ->
    len(Scheduler) =:= 0.

snapshot(Scheduler) ->
    #{requests => [Request || {_Priority, _Seq, Request} <- maps:get(pending, Scheduler, [])],
      seen => lists:sort(sets:to_list(maps:get(seen, Scheduler)))}.

restore(#{requests := Requests, seen := SeenList}) ->
    restore_requests(Requests, #{pending => [], seen => sets:from_list(SeenList), next_seq => 0});
restore(_) ->
    new().

restore_requests([], Scheduler) ->
    Scheduler;
restore_requests([Request | Rest], Scheduler0) ->
    Seq = maps:get(next_seq, Scheduler0, 0),
    Item = {-scrapling_request:priority(Request), Seq, Request},
    Pending0 = maps:get(pending, Scheduler0, []),
    Scheduler1 = Scheduler0#{pending => lists:sort(Pending0 ++ [Item]), next_seq => Seq + 1},
    restore_requests(Rest, Scheduler1).
