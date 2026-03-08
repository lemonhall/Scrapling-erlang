-module(scrapling_selector).

-include_lib("xmerl/include/xmerl.hrl").

-export([from_html/1, xpath/2, xpath/3, css/2, text/1, attribute/2, tag/1, children/1, re/2, re_first/2, get/1, getall/1, save/2, retrieve/1, relocate/2]).

from_html(Html) when is_binary(Html) ->
    from_html(unicode:characters_to_list(Html));
from_html(Html) when is_list(Html) ->
    {Doc, _Rest} = xmerl_scan:string(Html),
    Doc.

xpath(Query, Doc) when is_list(Query) ->
    xmerl_xpath:string(Query, Doc);
xpath(Query, Doc) when is_binary(Query) ->
    xpath(binary_to_list(Query), Doc).

xpath(Query, Doc, Opts) when is_map(Opts) ->
    Identifier = maps:get(identifier, Opts, Query),
    AutoSave = maps:get(auto_save, Opts, false),
    Adaptive = maps:get(adaptive, Opts, false),
    case xpath(Query, Doc) of
        [First | _] = Matches ->
            maybe_save(AutoSave, Identifier, First),
            Matches;
        [] when Adaptive =:= true ->
            case retrieve(Identifier) of
                undefined -> [];
                Saved ->
                    Relocated = relocate(Doc, Saved),
                    case {AutoSave, Relocated} of
                        {true, [First | _]} -> maybe_save(true, Identifier, First);
                        _ -> ok
                    end,
                    Relocated
            end;
        [] ->
            []
    end.

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

get(Node = #xmlElement{}) ->
    lists:flatten(xmerl:export_simple_content([Node], xmerl_html));
get(Node = #xmlText{}) ->
    text(Node);
get(Node = #xmlAttribute{}) ->
    text(Node).

getall(Node) ->
    [?MODULE:get(Node)].

save(Node, Identifier) ->
    scrapling_storage:save(Identifier, element_to_map(Node)).

retrieve(Identifier) ->
    scrapling_storage:retrieve(Identifier).

relocate(Doc, SavedElement) ->
    Candidates = all_elements(Doc),
    Scored = [{similarity_score(SavedElement, Candidate), Candidate} || Candidate <- Candidates],
    case Scored of
        [] -> [];
        _ ->
            Highest = lists:max([Score || {Score, _} <- Scored]),
            case Highest > 0 of
                true -> [Candidate || {Score, Candidate} <- Scored, Score =:= Highest];
                false -> []
            end
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

all_elements(Node = #xmlElement{}) ->
    [Node | lists:append([all_elements(Child) || Child <- children(Node)])];
all_elements(_) ->
    [].

element_to_map(Node = #xmlElement{attributes = Attributes, parents = Parents}) ->
    #{tag => tag(Node),
      attributes => maps:from_list([{atom_to_list(Attr#xmlAttribute.name), Attr#xmlAttribute.value} || Attr <- Attributes]),
      text => text(Node),
      path => element_path(Node),
      parent_name => parent_name(Parents),
      children => [tag(Child) || Child <- children(Node)]};
element_to_map(Node = #xmlText{}) ->
    #{tag => tag(Node), text => text(Node), attributes => #{}, path => [], parent_name => undefined, children => []};
element_to_map(Node = #xmlAttribute{}) ->
    #{tag => tag(Node), text => text(Node), attributes => #{}, path => [], parent_name => undefined, children => []}.

element_path(#xmlElement{name = Name, parents = Parents}) ->
    lists:reverse([atom_to_list(Name) | [atom_to_list(ParentName) || {ParentName, _} <- Parents]]).

parent_name([{ParentName, _} | _]) ->
    atom_to_list(ParentName);
parent_name([]) ->
    undefined.

similarity_score(Saved, Candidate) ->
    tag_score(Saved, Candidate) +
    text_score(Saved, Candidate) +
    parent_score(Saved, Candidate) +
    children_score(Saved, Candidate) +
    attribute_score(Saved, Candidate) +
    path_score(Saved, Candidate).

tag_score(#{tag := SavedTag}, Candidate) ->
    case SavedTag =:= tag(Candidate) of
        true -> 40;
        false -> 0
    end;
tag_score(_, _) ->
    0.

text_score(#{text := SavedText}, Candidate) ->
    case {SavedText, text(Candidate)} of
        {undefined, _} -> 0;
        {[], _} -> 0;
        {SavedText, SavedText} -> 30;
        _ -> 0
    end.

parent_score(#{parent_name := SavedParent}, #xmlElement{parents = Parents}) ->
    case {SavedParent, parent_name(Parents)} of
        {undefined, _} -> 0;
        {SavedParent, SavedParent} -> 10;
        _ -> 0
    end.

children_score(#{children := SavedChildren}, Candidate) ->
    CandidateChildren = [tag(Child) || Child <- children(Candidate)],
    common_count(SavedChildren, CandidateChildren) * 3.

attribute_score(#{attributes := SavedAttributes}, Candidate) ->
    CandidateAttributes = maps:get(attributes, element_to_map(Candidate), #{}),
    maps:fold(
      fun(Key, Value, Acc) ->
          case maps:get(Key, CandidateAttributes, undefined) of
              Value -> Acc + 10;
              _ -> Acc
          end
      end,
      0,
      SavedAttributes).

path_score(#{path := SavedPath}, Candidate) ->
    common_suffix_count(SavedPath, element_path(Candidate)) * 2.

common_count(Left, Right) ->
    common_count(Left, Right, 0).

common_count([], _, Acc) ->
    Acc;
common_count([Item | Rest], Right, Acc) ->
    case lists:member(Item, Right) of
        true -> common_count(Rest, Right, Acc + 1);
        false -> common_count(Rest, Right, Acc)
    end.

common_suffix_count(Left, Right) ->
    common_prefix_count(lists:reverse(Left), lists:reverse(Right)).

common_prefix_count([Item | LeftRest], [Item | RightRest]) ->
    1 + common_prefix_count(LeftRest, RightRest);
common_prefix_count(_, _) ->
    0.

maybe_save(true, Identifier, Node) ->
    save(Node, Identifier);
maybe_save(false, _Identifier, _Node) ->
    ok.

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
