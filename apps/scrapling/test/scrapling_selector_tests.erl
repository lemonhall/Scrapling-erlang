-module(scrapling_selector_tests).

-include_lib("eunit/include/eunit.hrl").

from_html_xpath_text_test() ->
    Html = read_fixture("parser_base.html"),
    Doc = scrapling_selector:from_html(Html),
    HeadingTexts = scrapling_selector:xpath("//h1/text()", Doc),
    ?assertEqual(["Scrapling Erlang"], [scrapling_selector:text(Node) || Node <- HeadingTexts]).

xpath_attribute_selection_test() ->
    Html = read_fixture("parser_base.html"),
    Doc = scrapling_selector:from_html(Html),
    Items = scrapling_selector:xpath("//*[@id='items']/li", Doc),
    ?assertEqual(2, length(Items)),
    ?assertEqual("1", scrapling_selector:attribute("data-id", lists:nth(1, Items))),
    ?assertEqual("alpha", scrapling_selector:text(lists:nth(1, Items))).

css_simple_selectors_test() ->
    Html = read_fixture("parser_base.html"),
    Doc = scrapling_selector:from_html(Html),
    HeroHeading = scrapling_selector:css(".hero h1", Doc),
    Summary = scrapling_selector:css("[data-role='summary']", Doc),
    Items = scrapling_selector:css("#items li", Doc),
    ?assertEqual(["Scrapling Erlang"], [scrapling_selector:text(Node) || Node <- HeroHeading]),
    ?assertEqual(["Parser smoke fixture"], [scrapling_selector:text(Node) || Node <- Summary]),
    ?assertEqual(["alpha", "beta"], [scrapling_selector:text(Node) || Node <- Items]).

children_navigation_test() ->
    Html = read_fixture("parser_base.html"),
    Doc = scrapling_selector:from_html(Html),
    [Main] = scrapling_selector:xpath("//*[@id='app']", Doc),
    Children = scrapling_selector:children(Main),
    ?assertEqual(["section", "ul"], [scrapling_selector:tag(Node) || Node <- Children]),
    ?assertEqual("hero", scrapling_selector:attribute("class", lists:nth(1, Children))),
    ?assertEqual("items", scrapling_selector:attribute("id", lists:nth(2, Children))).

parent_and_sibling_navigation_test() ->
    Html = read_fixture("parser_base.html"),
    Doc = scrapling_selector:from_html(Html),
    [Hero] = scrapling_selector:css(".hero", Doc),
    Parent = scrapling_selector:parent(Hero),
    Siblings = scrapling_selector:siblings(Hero),
    ?assertEqual("main", scrapling_selector:tag(Parent)),
    ?assertEqual(["ul"], [scrapling_selector:tag(Node) || Node <- Siblings]),
    ?assertEqual("items", scrapling_selector:attribute("id", lists:nth(1, Siblings))).

next_previous_navigation_test() ->
    Html = read_fixture("parser_base.html"),
    Doc = scrapling_selector:from_html(Html),
    [First, Second] = scrapling_selector:css("#items li", Doc),
    ?assertEqual("2", scrapling_selector:attribute("data-id", scrapling_selector:next(First))),
    ?assertEqual("1", scrapling_selector:attribute("data-id", scrapling_selector:previous(Second))).

find_ancestor_test() ->
    Html = read_fixture("parser_base.html"),
    Doc = scrapling_selector:from_html(Html),
    [Link] = scrapling_selector:css("a", Doc),
    Main = scrapling_selector:find_ancestor(Link, fun(Node) -> scrapling_selector:attribute("id", Node) =:= "app" end),
    ?assertEqual("main", scrapling_selector:tag(Main)).

selector_regex_test() ->
    Html = read_fixture("parser_base.html"),
    Doc = scrapling_selector:from_html(Html),
    [Heading] = scrapling_selector:xpath("//h1", Doc),
    ?assertEqual(["Scrapling", "Erlang"], scrapling_selector:re("[A-Z][a-z]+", Heading)),
    ?assertEqual("Erlang", scrapling_selector:re_first("Erlang", Heading)).

selector_getters_test() ->
    Html = read_fixture("parser_base.html"),
    Doc = scrapling_selector:from_html(Html),
    [Heading] = scrapling_selector:xpath("//h1", Doc),
    [HeadingText] = scrapling_selector:xpath("//h1/text()", Doc),
    ?assertEqual("<h1>Scrapling Erlang</h1>", scrapling_selector:get(Heading)),
    ?assertEqual(["<h1>Scrapling Erlang</h1>"], scrapling_selector:getall(Heading)),
    ?assertEqual("Scrapling Erlang", scrapling_selector:get(HeadingText)).

css_pseudo_text_and_attr_test() ->
    Html = read_fixture("parser_base.html"),
    Doc = scrapling_selector:from_html(Html),
    LinkTexts = scrapling_selector:css("a::text", Doc),
    LinkHrefs = scrapling_selector:css("a::attr(href)", Doc),
    ?assertEqual(["Read docs"], [scrapling_selector:get(Node) || Node <- LinkTexts]),
    ?assertEqual(["/docs"], [scrapling_selector:get(Node) || Node <- LinkHrefs]).

find_all_and_find_test() ->
    Html = read_fixture("parser_base.html"),
    Doc = scrapling_selector:from_html(Html),
    Items = scrapling_selector:find_all(Doc, #{tag => "li"}),
    Summary = scrapling_selector:find(Doc, #{tag => "p", attributes => #{"data-role" => "summary"}}),
    Link = scrapling_selector:find(Doc, #{text => "Read docs"}),
    ?assertEqual(2, length(Items)),
    ?assertEqual("Parser smoke fixture", scrapling_selector:text(Summary)),
    ?assertEqual("/docs", scrapling_selector:attribute("href", Link)).

read_fixture(Name) ->
    Path = filename:join(["apps", "scrapling", "test", "fixtures", Name]),
    {ok, Html} = file:read_file(Path),
    Html.
