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

read_fixture(Name) ->
    Path = filename:join(["apps", "scrapling", "test", "fixtures", Name]),
    {ok, Html} = file:read_file(Path),
    Html.
