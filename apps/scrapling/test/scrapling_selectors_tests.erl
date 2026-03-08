-module(scrapling_selectors_tests).

-include_lib("eunit/include/eunit.hrl").

selectors_getters_test() ->
    Doc = fixture_doc(),
    Nodes = scrapling_selector:xpath("//*[@id='items']/li", Doc),
    Selectors = scrapling_selectors:from_nodes(Nodes),
    ?assertEqual(2, scrapling_selectors:length(Selectors)),
    ?assertEqual("1", scrapling_selector:attribute("data-id", scrapling_selectors:first(Selectors))),
    ?assertEqual("2", scrapling_selector:attribute("data-id", scrapling_selectors:last(Selectors))),
    ?assertEqual("<li data-id=\"1\">alpha</li>", scrapling_selectors:get(Selectors)),
    ?assertEqual(["<li data-id=\"1\">alpha</li>", "<li data-id=\"2\">beta</li>"], scrapling_selectors:getall(Selectors)).

selectors_chaining_test() ->
    Doc = fixture_doc(),
    Sections = scrapling_selectors:from_nodes(scrapling_selector:xpath("//section", Doc)),
    Headings = scrapling_selectors:css("h1", Sections),
    Summaries = scrapling_selectors:xpath(".//p/text()", Sections),
    ?assertEqual(["<h1>Scrapling Erlang</h1>"], scrapling_selectors:getall(Headings)),
    ?assertEqual(["Parser smoke fixture"], scrapling_selectors:getall(Summaries)).

selectors_regex_test() ->
    Doc = fixture_doc(),
    Items = scrapling_selectors:from_nodes(scrapling_selector:xpath("//*[@id='items']/li", Doc)),
    ?assertEqual(["alpha", "beta"], scrapling_selectors:re("[a-z]+", Items)),
    ?assertEqual("beta", scrapling_selectors:re_first("beta", Items)).

selectors_serialization_test() ->
    Doc = fixture_doc(),
    Items = scrapling_selectors:from_nodes(scrapling_selector:xpath("//*[@id='items']/li", Doc)),
    ?assertEqual("<li data-id=\"1\">alpha</li>", scrapling_selectors:get(Items)),
    ?assertEqual(["<li data-id=\"1\">alpha</li>", "<li data-id=\"2\">beta</li>"], scrapling_selectors:getall(Items)).

fixture_doc() ->
    Path = filename:join(["apps", "scrapling", "test", "fixtures", "parser_base.html"]),
    {ok, Html} = file:read_file(Path),
    scrapling_selector:from_html(Html).
