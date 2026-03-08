-module(scrapling_checkpoint_tests).

-include_lib("eunit/include/eunit.hrl").

checkpoint_roundtrip_test() ->
    Manager = scrapling_checkpoint:new(temp_crawldir()),
    Request = scrapling_request:new(
                "https://example.com/detail",
                #{sid => <<"special">>,
                  priority => 7,
                  dont_filter => true,
                  meta => #{item_id => 42},
                  proxy => <<"http://proxy.local:8080">>}),
    Data = #{requests => [Request], seen => [<<"fp1">>, <<"fp2">>]},
    try
        ok = scrapling_checkpoint:save(Manager, Data),
        ?assertEqual(true, scrapling_checkpoint:has_checkpoint(Manager)),
        {ok, Loaded} = scrapling_checkpoint:load(Manager),
        [Restored] = maps:get(requests, Loaded),
        ?assertEqual(scrapling_request:url(Request), scrapling_request:url(Restored)),
        ?assertEqual(scrapling_request:sid(Request), scrapling_request:sid(Restored)),
        ?assertEqual(scrapling_request:priority(Request), scrapling_request:priority(Restored)),
        ?assertEqual(scrapling_request:dont_filter(Request), scrapling_request:dont_filter(Restored)),
        ?assertEqual(scrapling_request:meta(Request), scrapling_request:meta(Restored)),
        ?assertEqual(scrapling_request:session_opts(Request), scrapling_request:session_opts(Restored)),
        ?assertEqual([<<"fp1">>, <<"fp2">>], maps:get(seen, Loaded))
    after
        ok = scrapling_checkpoint:cleanup(Manager)
    end.

checkpoint_cleanup_test() ->
    Manager = scrapling_checkpoint:new(temp_crawldir()),
    try
        ok = scrapling_checkpoint:save(Manager, #{requests => [], seen => []}),
        ?assertEqual(true, scrapling_checkpoint:has_checkpoint(Manager)),
        ok = scrapling_checkpoint:cleanup(Manager),
        ?assertEqual(false, scrapling_checkpoint:has_checkpoint(Manager))
    after
        ok = scrapling_checkpoint:cleanup(Manager)
    end.

temp_crawldir() ->
    filename:join(["_build", "test", "checkpoint", integer_to_list(erlang:unique_integer([positive, monotonic]))]).
