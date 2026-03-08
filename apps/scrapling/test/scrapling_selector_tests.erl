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

selector_regex_test() ->
    Html = read_fixture("parser_base.html"),
    Doc = scrapling_selector:from_html(Html),
    [Heading] = scrapling_selector:xpath("//h1", Doc),
    ?assertEqual(["Scrapling", "Erlang"], scrapling_selector:re("[A-Z][a-z]+", Heading)),
    ?assertEqual("Erlang", scrapling_selector:re_first("Erlang", Heading)).

read_fixture(Name) ->
    Path = filename:join(["apps", "scrapling", "test", "fixtures", Name]),
    {ok, Html} = file:read_file(Path),
    Html.
