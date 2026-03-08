-module(scrapling_selector).

-include_lib("xmerl/include/xmerl.hrl").

-export([from_html/1, xpath/2, xpath/3, css/2, css/3, text/1, attribute/2, tag/1, children/1, parent/1, siblings/1, next/1, previous/1, find_ancestor/2, re/2, re_first/2, get/1, getall/1, save/2, retrieve/1, relocate/2, find_all/2, find/2]).

from_html(Html) when is_binary(Html) ->
    from_html(unicode:characters_to_list(Html));
from_html(Html) when is_list(Html) ->
    {Doc, _Rest} = xmerl_scan:string(Html),
    Doc.

xpath(Query, Doc) when is_list(Query) ->
    Root = root_context(Doc),
    wrap_results(xmerl_xpath:string(Query, unwrap(Doc)), Root);
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

css(Selector, Doc, Opts) when is_map(Opts) ->
    Identifier = maps:get(identifier, Opts, Selector),
    AutoSave = maps:get(auto_save, Opts, false),
    Adaptive = maps:get(adaptive, Opts, false),
    case css(Selector, Doc) of
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

text(#{node := Node}) ->
    text(Node);
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

attribute(Name, #{node := Node}) ->
    attribute(Name, Node);
attribute(Name, #xmlElement{attributes = Attributes}) when is_binary(Name) ->
    attribute(binary_to_list(Name), #xmlElement{attributes = Attributes});
attribute(Name, #xmlElement{attributes = Attributes}) when is_list(Name) ->
    case [Attr#xmlAttribute.value || Attr <- Attributes, atom_to_list(Attr#xmlAttribute.name) =:= Name] of
        [Value | _] -> Value;
        [] -> undefined
    end.

tag(#{node := Node}) ->
    tag(Node);
tag(#xmlElement{name = Name}) ->
    atom_to_list(Name);
tag(#xmlText{}) ->
    "#text";
tag(#xmlAttribute{name = Name}) ->
    "@" ++ atom_to_list(Name).

children(#{root := Root, node := #xmlElement{content = Content}}) ->
    [wrap_node(Node, Root) || Node <- Content, is_element_node(Node)];
children(#xmlElement{content = Content}) ->
    [Node || Node <- Content, is_element_node(Node)];
children(_) ->
    [].

parent(#{root := Root, node := Node}) ->
    wrap_or_undefined(parent_raw(Node, Root), Root);
parent(_) ->
    undefined.

siblings(Node) ->
    case parent(Node) of
        undefined -> [];
        Parent -> [Sibling || Sibling <- children(Parent), not same_node(Sibling, Node)]
    end.

next(Node) ->
    case parent(Node) of
        undefined -> undefined;
        Parent -> next_sibling(children(Parent), Node)
    end.

previous(Node) ->
    case parent(Node) of
        undefined -> undefined;
        Parent -> previous_sibling(children(Parent), Node)
    end.

find_ancestor(Node, Predicate) when is_function(Predicate, 1) ->
    case parent(Node) of
        undefined -> undefined;
        Ancestor ->
            case Predicate(Ancestor) of
                true -> Ancestor;
                false -> find_ancestor(Ancestor, Predicate)
            end
    end;
find_ancestor(Node, Query) when is_map(Query) ->
    find_ancestor(Node, fun(Ancestor) -> matches_query(Ancestor, Query) end).

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

get(#{node := Node}) ->
    ?MODULE:get(Node);
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
    Root = root_context(Doc),
    Candidates = all_elements(unwrap(Doc)),
    Scored = [{similarity_score(SavedElement, Candidate), Candidate} || Candidate <- Candidates],
    case Scored of
        [] -> [];
        _ ->
            Highest = lists:max([Score || {Score, _} <- Scored]),
            case Highest > 0 of
                true -> [wrap_node(Candidate, Root) || {Score, Candidate} <- Scored, Score =:= Highest];
                false -> []
            end
    end.

find_all(Doc, Query) when is_map(Query) ->
    Root = root_context(Doc),
    [wrap_node(Node, Root) || Node <- all_elements(unwrap(Doc)), matches_query(Node, Query)].

find(Doc, Query) when is_map(Query) ->
    case find_all(Doc, Query) of
        [Match | _] -> Match;
        [] -> undefined
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

element_to_map(#{node := Node}) ->
    element_to_map(Node);
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

wrap_results(Results, Root) ->
    [wrap_node(Result, Root) || Result <- Results].

wrap_node(Node = #xmlElement{}, Root) ->
    #{root => unwrap(Root), node => Node};
wrap_node(Node = #xmlText{}, Root) ->
    #{root => unwrap(Root), node => Node};
wrap_node(Node = #xmlAttribute{}, Root) ->
    #{root => unwrap(Root), node => Node};
wrap_node(Value, _Root) ->
    Value.

wrap_or_undefined(undefined, _Root) ->
    undefined;
wrap_or_undefined(Node, Root) ->
    wrap_node(Node, Root).

unwrap(#{node := Node}) ->
    Node;
unwrap(Node) ->
    Node.

root_context(#{root := Root}) ->
    Root;
root_context(Root) ->
    Root.

parent_raw(#xmlElement{parents = [{ParentName, ParentPos} | Ancestors]}, Root) ->
    find_element_by_locator(ParentName, ParentPos, Ancestors, Root);
parent_raw(#xmlText{parents = [{ParentName, ParentPos} | Ancestors]}, Root) ->
    find_element_by_locator(ParentName, ParentPos, Ancestors, Root);
parent_raw(#xmlAttribute{parents = [{ParentName, ParentPos} | Ancestors]}, Root) ->
    find_element_by_locator(ParentName, ParentPos, Ancestors, Root);
parent_raw(_, _Root) ->
    undefined.

find_element_by_locator(Name, Pos, Parents, Root) ->
    first_or_undefined([
        Node || Node = #xmlElement{name = CandidateName, pos = CandidatePos, parents = CandidateParents} <- all_elements(unwrap(Root)),
                CandidateName =:= Name,
                CandidatePos =:= Pos,
                CandidateParents =:= Parents
    ]).

same_node(Left, Right) ->
    unwrap(Left) =:= unwrap(Right).

next_sibling([], _Node) ->
    undefined;
next_sibling([Current | Rest], Node) ->
    case same_node(Current, Node) of
        true -> first_or_undefined(Rest);
        false -> next_sibling(Rest, Node)
    end.

previous_sibling(Nodes, Node) ->
    previous_sibling(Nodes, Node, undefined).

previous_sibling([], _Node, Previous) ->
    Previous;
previous_sibling([Current | Rest], Node, Previous) ->
    case same_node(Current, Node) of
        true -> Previous;
        false -> previous_sibling(Rest, Node, Current)
    end.

first_or_undefined([First | _]) ->
    First;
first_or_undefined([]) ->
    undefined.

matches_query(Node, Query) ->
    tag_matches(Node, maps:get(tag, Query, undefined)) andalso
    text_matches(Node, maps:get(text, Query, undefined)) andalso
    attributes_match(Node, maps:get(attributes, Query, #{})).

tag_matches(_Node, undefined) ->
    true;
tag_matches(Node, TagName) ->
    tag(Node) =:= TagName.

text_matches(_Node, undefined) ->
    true;
text_matches(Node, Value) ->
    text(Node) =:= Value.

attributes_match(_Node, Attrs) when map_size(Attrs) =:= 0 ->
    true;
attributes_match(Node, Attrs) ->
    maps:fold(
      fun(Key, Value, Acc) ->
          Acc andalso attribute(Key, Node) =:= Value
      end,
      true,
      Attrs).

css_to_xpath(Selector) ->
    Trimmed = string:trim(Selector),
    case parse_css_pseudo(Trimmed) of
        {text, Base} -> css_to_xpath_base(Base) ++ "/text()";
        {attr, Base, Attr} -> css_to_xpath_base(Base) ++ "/@" ++ Attr;
        none -> css_to_xpath_base(Trimmed)
    end.

css_to_xpath_base(Selector) ->
    Parts = [simple_selector_to_xpath(Token) || Token <- string:tokens(string:trim(Selector), " "), Token =/= []],
    "//" ++ string:join(Parts, "//").

parse_css_pseudo(Selector) ->
    case re:run(Selector, "^(.*)::attr\\(([^)]+)\\)$", [{capture, [1,2], list}]) of
        {match, [Base, Attr]} -> {attr, string:trim(Base), string:trim(Attr)};
        nomatch ->
            case lists:suffix("::text", Selector) of
                true -> {text, string:trim(lists:sublist(Selector, erlang:length(Selector) - erlang:length("::text")))};
                false -> none
            end
    end.

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
    ["contains(@class, '" ++ Value ++ "')" || Value <- Values].
