-module(scrapling_scheduler_tests).

-include_lib("eunit/include/eunit.hrl").

scheduler_starts_empty_test() ->
    Scheduler = scrapling_scheduler:new(),
    ?assertEqual(0, scrapling_scheduler:len(Scheduler)),
    ?assertEqual(true, scrapling_scheduler:is_empty(Scheduler)).

scheduler_enqueue_priority_and_dedup_test() ->
    Scheduler0 = scrapling_scheduler:new(),
    High = scrapling_request:new("https://example.com/high", #{priority => 10, sid => "http"}),
    Low = scrapling_request:new("https://example.com/low", #{priority => 1, sid => "http"}),
    Duplicate = scrapling_request:new("https://example.com/high", #{priority => 10, sid => "http"}),
    {true, Scheduler1} = scrapling_scheduler:enqueue(High, Scheduler0),
    {true, Scheduler2} = scrapling_scheduler:enqueue(Low, Scheduler1),
    {false, Scheduler3} = scrapling_scheduler:enqueue(Duplicate, Scheduler2),
    ?assertEqual(2, scrapling_scheduler:len(Scheduler3)),
    {ok, First, Scheduler4} = scrapling_scheduler:dequeue(Scheduler3),
    {ok, Second, Scheduler5} = scrapling_scheduler:dequeue(Scheduler4),
    ?assertEqual(<<"https://example.com/high">>, scrapling_request:url(First)),
    ?assertEqual(<<"https://example.com/low">>, scrapling_request:url(Second)),
    ?assertEqual(true, scrapling_scheduler:is_empty(Scheduler5)).

scheduler_snapshot_restore_and_dont_filter_test() ->
    Scheduler0 = scrapling_scheduler:new(),
    One = scrapling_request:new("https://example.com/1", #{priority => 5, sid => "http"}),
    Two = scrapling_request:new("https://example.com/1", #{priority => 1, sid => "http", dont_filter => true}),
    Three = scrapling_request:new("https://example.com/3", #{priority => 3, sid => "stealth"}),
    {true, Scheduler1} = scrapling_scheduler:enqueue(One, Scheduler0),
    {true, Scheduler2} = scrapling_scheduler:enqueue(Two, Scheduler1),
    {true, Scheduler3} = scrapling_scheduler:enqueue(Three, Scheduler2),
    Snapshot = scrapling_scheduler:snapshot(Scheduler3),
    ?assertEqual(3, length(maps:get(requests, Snapshot))),
    ?assertEqual(2, length(maps:get(seen, Snapshot))),

    Restored = scrapling_scheduler:restore(Snapshot),
    {ok, First, Restored1} = scrapling_scheduler:dequeue(Restored),
    {ok, Second, Restored2} = scrapling_scheduler:dequeue(Restored1),
    {ok, Third, _Restored3} = scrapling_scheduler:dequeue(Restored2),
    ?assertEqual(<<"https://example.com/1">>, scrapling_request:url(First)),
    ?assertEqual(<<"https://example.com/3">>, scrapling_request:url(Second)),
    ?assertEqual(<<"https://example.com/1">>, scrapling_request:url(Third)).
