-module(scrapling_session_manager_tests).

-include_lib("eunit/include/eunit.hrl").

session_manager_defaults_test() ->
    Manager0 = scrapling_session_manager:new(),
    ?assertEqual(0, scrapling_session_manager:len(Manager0)),
    ?assertMatch({error, #{type := <<"no_sessions_registered">>}}, scrapling_session_manager:default_session_id(Manager0)),

    {ok, Manager1} = scrapling_session_manager:add(<<"default">>, scrapling_session_manager:custom(fun default_fetch/1), Manager0),
    {ok, <<"default">>} = scrapling_session_manager:default_session_id(Manager1),
    ?assertEqual([<<"default">>], scrapling_session_manager:session_ids(Manager1)).

session_manager_duplicate_id_error_test() ->
    Manager0 = scrapling_session_manager:new(),
    {ok, Manager1} = scrapling_session_manager:add(<<"dup">>, scrapling_session_manager:custom(fun default_fetch/1), Manager0),
    ?assertMatch({error, #{type := <<"duplicate_session_id">>}},
                 scrapling_session_manager:add(<<"dup">>, scrapling_session_manager:custom(fun special_fetch/1), Manager1)).

session_manager_fetch_routes_and_merges_meta_test() ->
    Manager0 = scrapling_session_manager:new(),
    {ok, Manager1} = scrapling_session_manager:add(<<"default">>, scrapling_session_manager:custom(fun default_fetch/1), Manager0),
    {ok, Manager2} = scrapling_session_manager:add(<<"special">>, scrapling_session_manager:custom(fun special_fetch/1), #{default => false}, Manager1),

    DefaultRequest = scrapling_request:new("https://example.com/default", #{meta => #{trace => <<"t1">>}}),
    {ok, DefaultResponse, Manager3} = scrapling_session_manager:fetch(DefaultRequest, Manager2),
    ?assertEqual(Manager2, Manager3),
    ?assertEqual(<<"default">>, scrapling_response:body(DefaultResponse)),
    ?assertEqual(<<"t1">>, maps:get(trace, scrapling_response:meta(DefaultResponse))),
    ?assertEqual(<<"custom-default">>, maps:get(engine, scrapling_response:meta(DefaultResponse))),
    ?assertEqual(DefaultRequest, maps:get(request, DefaultResponse)),

    SpecialRequest = scrapling_request:new("https://example.com/special", #{sid => <<"special">>, meta => #{trace => <<"t2">>}}),
    {ok, SpecialResponse, _Manager4} = scrapling_session_manager:fetch(SpecialRequest, Manager3),
    ?assertEqual(<<"special">>, scrapling_response:body(SpecialResponse)),
    ?assertEqual(<<"t2">>, maps:get(trace, scrapling_response:meta(SpecialResponse))),
    ?assertEqual(<<"custom-special">>, maps:get(engine, scrapling_response:meta(SpecialResponse))).

session_manager_missing_session_error_test() ->
    Manager0 = scrapling_session_manager:new(),
    Request = scrapling_request:new("https://example.com/missing", #{sid => <<"ghost">>}),
    ?assertMatch({error, #{type := <<"session_not_found">>}, _}, scrapling_session_manager:fetch(Request, Manager0)).

default_fetch(_Request) ->
    scrapling_response:new(200, <<"OK">>, [{"content-type", "text/plain"}], <<"default">>, <<"https://example.com/default">>, get, [], #{engine => <<"custom-default">>}).

special_fetch(_Request) ->
    scrapling_response:new(200, <<"OK">>, [{"content-type", "text/plain"}], <<"special">>, <<"https://example.com/special">>, get, [], #{engine => <<"custom-special">>}).
