-module(scrapling_adaptive_tests).

-include_lib("eunit/include/eunit.hrl").

adaptive_save_retrieve_test() ->
    ok = scrapling_storage:reset(),
    Base = fixture_doc("parser_base.html"),
    [Heading] = scrapling_selector:xpath("//h1", Base),
    ok = scrapling_selector:save(Heading, "hero_heading"),
    Saved = scrapling_selector:retrieve("hero_heading"),
    ?assertEqual("h1", maps:get(tag, Saved)),
    ?assertEqual("Scrapling Erlang", maps:get(text, Saved)),
    ?assert(is_list(maps:get(path, Saved))).

adaptive_relocate_test() ->
    ok = scrapling_storage:reset(),
    Base = fixture_doc("parser_base.html"),
    Changed = fixture_doc("parser_changed.html"),
    [Heading] = scrapling_selector:xpath("//h1", Base),
    ok = scrapling_selector:save(Heading, "hero_heading"),
    Saved = scrapling_selector:retrieve("hero_heading"),
    [Relocated | _] = scrapling_selector:relocate(Changed, Saved),
    ?assertEqual("h1", scrapling_selector:tag(Relocated)),
    ?assertEqual("Scrapling Erlang", scrapling_selector:text(Relocated)).

adaptive_xpath_with_auto_save_and_relocate_test() ->
    ok = scrapling_storage:reset(),
    Base = fixture_doc("parser_base.html"),
    Changed = fixture_doc("parser_changed.html"),
    Initial = scrapling_selector:xpath("//section[@class='hero']/h1", Base, #{auto_save => true, identifier => "hero_heading"}),
    ?assertEqual(["Scrapling Erlang"], [scrapling_selector:text(Node) || Node <- Initial]),
    Relocated = scrapling_selector:xpath("//section[@class='hero']/h1", Changed, #{adaptive => true, identifier => "hero_heading"}),
    ?assertEqual(["Scrapling Erlang"], [scrapling_selector:text(Node) || Node <- Relocated]).

fixture_doc(Name) ->
    Path = filename:join(["apps", "scrapling", "test", "fixtures", Name]),
    {ok, Html} = file:read_file(Path),
    scrapling_selector:from_html(Html).
