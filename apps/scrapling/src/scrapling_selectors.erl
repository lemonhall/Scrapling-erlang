-module(scrapling_selectors).

-compile({no_auto_import, [length/1]}).

-export([from_nodes/1, to_list/1, length/1, first/1, last/1, get/1, getall/1, xpath/2, css/2]).

from_nodes(Nodes) when is_list(Nodes) ->
    #{type => selectors, nodes => Nodes}.

to_list(#{type := selectors, nodes := Nodes}) ->
    Nodes.

length(Selectors) ->
    erlang:length(to_list(Selectors)).

first(Selectors) ->
    case to_list(Selectors) of
        [Node | _] -> Node;
        [] -> undefined
    end.

last(Selectors) ->
    case to_list(Selectors) of
        [] -> undefined;
        Nodes -> lists:last(Nodes)
    end.

get(Selectors) ->
    case first(Selectors) of
        undefined -> undefined;
        Node -> scrapling_selector:text(Node)
    end.

getall(Selectors) ->
    [scrapling_selector:text(Node) || Node <- to_list(Selectors)].

xpath(Query, Selectors) ->
    from_nodes(flatten([scrapling_selector:xpath(Query, Node) || Node <- to_list(Selectors)])).

css(Query, Selectors) ->
    from_nodes(flatten([scrapling_selector:css(Query, Node) || Node <- to_list(Selectors)])).

flatten(Lists) ->
    lists:append(Lists).
