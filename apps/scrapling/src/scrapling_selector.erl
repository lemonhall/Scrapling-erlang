-module(scrapling_selector).

-include_lib("xmerl/include/xmerl.hrl").

-export([from_html/1, xpath/2, text/1, attribute/2]).

from_html(Html) when is_binary(Html) ->
    from_html(unicode:characters_to_list(Html));
from_html(Html) when is_list(Html) ->
    {Doc, _Rest} = xmerl_scan:string(Html),
    Doc.

xpath(Query, Doc) when is_list(Query) ->
    xmerl_xpath:string(Query, Doc);
xpath(Query, Doc) when is_binary(Query) ->
    xpath(binary_to_list(Query), Doc).

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

keep_text(#xmlText{}) ->
    true;
keep_text(#xmlElement{}) ->
    true;
keep_text(_) ->
    false.
