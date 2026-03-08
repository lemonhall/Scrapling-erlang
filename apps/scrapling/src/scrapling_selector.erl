-module(scrapling_selector).

-include_lib("xmerl/include/xmerl.hrl").

-export([from_html/1, xpath/2, css/2, text/1, attribute/2, tag/1, children/1, re/2, re_first/2]).

from_html(Html) when is_binary(Html) ->
    from_html(unicode:characters_to_list(Html));
from_html(Html) when is_list(Html) ->
    {Doc, _Rest} = xmerl_scan:string(Html),
    Doc.

xpath(Query, Doc) when is_list(Query) ->
    xmerl_xpath:string(Query, Doc);
xpath(Query, Doc) when is_binary(Query) ->
    xpath(binary_to_list(Query), Doc).

css(Selector, Doc) when is_binary(Selector) ->
    css(binary_to_list(Selector), Doc);
css(Selector, Doc) when is_list(Selector) ->
    xpath(css_to_xpath(Selector), Doc).

text(#xmlText{value = Value}) ->
    string:trim(Value);
text(#xmlAttribute{value = Value}) ->
    string:trim(Value);
text(#xmlElement{content = Content}) ->
    string:trim(lists:flatten([text(Node) || Node <- Content, keep_text(Node)]));
text(Value) when is_list(Value) ->
    string:trim(Value);
text(Value) when is_binary(Value) ->
    string:trim(binary_to_list(Value)).

attribute(Name, #xmlElement{attributes = Attributes}) when is_binary(Name) ->
    attribute(binary_to_list(Name), #xmlElement{attributes = Attributes});
attribute(Name, #xmlElement{attributes = Attributes}) when is_list(Name) ->
    case [Attr#xmlAttribute.value || Attr <- Attributes, atom_to_list(Attr#xmlAttribute.name) =:= Name] of
        [Value | _] -> Value;
        [] -> undefined
    end.

tag(#xmlElement{name = Name}) ->
    atom_to_list(Name);
tag(#xmlText{}) ->
    "#text";
tag(#xmlAttribute{name = Name}) ->
    "@" ++ atom_to_list(Name).

children(#xmlElement{content = Content}) ->
    [Node || Node <- Content, is_element_node(Node)];
children(_) ->
    [].

re(Pattern, Node) ->
    case re:run(text(Node), Pattern, [global, {capture, first, list}]) of
        {match, Matches} -> [Match || [Match] <- Matches];
        nomatch -> []
    end.

re_first(Pattern, Node) ->
    case re:run(text(Node), Pattern, [{capture, first, list}]) of
        {match, [Match]} -> Match;
        nomatch -> undefined
    end.

keep_text(#xmlText{}) ->
    true;
keep_text(#xmlElement{}) ->
    true;
keep_text(_) ->
    false.

is_element_node(#xmlElement{}) ->
    true;
is_element_node(_) ->
    false.

css_to_xpath(Selector) ->
    Parts = [simple_selector_to_xpath(Token) || Token <- string:tokens(string:trim(Selector), " "), Token =/= []],
    "//" ++ string:join(Parts, "//").

simple_selector_to_xpath(Token) ->
    Parsed = parse_simple_selector(Token, #{tag => [], id => undefined, classes => [], attrs => []}),
    Tag = case maps:get(tag, Parsed) of [] -> "*"; Value -> Value end,
    Predicates =
        id_predicate(maps:get(id, Parsed)) ++
        class_predicates(maps:get(classes, Parsed)) ++
        attr_predicates(maps:get(attrs, Parsed)),
    case Predicates of
        [] -> Tag;
        _ -> Tag ++ "[" ++ string:join(Predicates, " and ") ++ "]"
    end.

parse_simple_selector([], Acc) ->
    Acc;
parse_simple_selector("#" ++ Rest, Acc) ->
    {Value, Tail} = take_identifier(Rest),
    parse_simple_selector(Tail, Acc#{id => Value});
parse_simple_selector("." ++ Rest, Acc) ->
    {Value, Tail} = take_identifier(Rest),
    parse_simple_selector(Tail, Acc#{classes => maps:get(classes, Acc) ++ [Value]});
parse_simple_selector("[" ++ Rest, Acc) ->
    {Value, Tail} = take_until_closing_bracket(Rest, []),
    parse_simple_selector(Tail, Acc#{attrs => maps:get(attrs, Acc) ++ [parse_attribute_selector(Value)]});
parse_simple_selector(Token, Acc = #{tag := []}) ->
    {Value, Tail} = take_identifier(Token),
    parse_simple_selector(Tail, Acc#{tag => Value});
parse_simple_selector([_ | Tail], Acc) ->
    parse_simple_selector(Tail, Acc).

take_identifier(Input) ->
    take_identifier(Input, []).

take_identifier([], Acc) ->
    {lists:reverse(Acc), []};
take_identifier([Char | Rest], Acc) when Char =:= $#; Char =:= $.; Char =:= $[; Char =:= $ ; Char =:= $] ->
    {lists:reverse(Acc), [Char | Rest]};
take_identifier([Char | Rest], Acc) ->
    take_identifier(Rest, [Char | Acc]).

take_until_closing_bracket([], Acc) ->
    {lists:reverse(Acc), []};
take_until_closing_bracket("]" ++ Rest, Acc) ->
    {lists:reverse(Acc), Rest};
take_until_closing_bracket([Char | Rest], Acc) ->
    take_until_closing_bracket(Rest, [Char | Acc]).

parse_attribute_selector(Raw) ->
    Trimmed = string:trim(Raw),
    case string:split(Trimmed, "=", all) of
        [Name, Value] ->
            {string:trim(Name), unquote(string:trim(Value))};
        [Name] ->
            {string:trim(Name), undefined}
    end.

unquote([$' | Rest]) ->
    lists:reverse(tl(lists:reverse(Rest)));
unquote([$" | Rest]) ->
    lists:reverse(tl(lists:reverse(Rest)));
unquote(Value) ->
    Value.

id_predicate(undefined) ->
    [];
id_predicate(Value) ->
    ["@id='" ++ Value ++ "'"].

attr_predicates(Values) ->
    [attr_predicate(Name, Value) || {Name, Value} <- Values].

attr_predicate(Name, undefined) ->
    "@" ++ Name;
attr_predicate(Name, Value) ->
    "@" ++ Name ++ "='" ++ Value ++ "'".

class_predicates(Values) ->
    ["@class='" ++ Value ++ "'" || Value <- Values].
