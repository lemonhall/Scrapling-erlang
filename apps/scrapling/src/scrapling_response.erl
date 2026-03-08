-module(scrapling_response).

-export([
    new/8,
    status_code/1,
    reason_phrase/1,
    headers/1,
    header/2,
    body/1,
    document/1,
    url/1,
    method/1,
    request_headers/1,
    cookies/1,
    meta/1,
    css/2,
    xpath/2
]).

new(StatusCode, ReasonPhrase, Headers, Body, Url, Method, RequestHeaders, Meta) ->
    NormalizedHeaders = normalize_header_list(Headers),
    NormalizedRequestHeaders = normalize_header_list(RequestHeaders),
    NormalizedBody = to_binary(Body),
    #{status_code => StatusCode,
      reason_phrase => to_binary(ReasonPhrase),
      headers => headers_to_map(NormalizedHeaders),
      raw_headers => NormalizedHeaders,
      body => NormalizedBody,
      url => to_binary(Url),
      method => method_value(Method),
      request_headers => headers_to_map(NormalizedRequestHeaders),
      cookies => extract_cookies(NormalizedHeaders),
      meta => Meta,
      document => maybe_document(NormalizedHeaders, NormalizedBody)}.

status_code(Response) ->
    maps:get(status_code, Response).

reason_phrase(Response) ->
    maps:get(reason_phrase, Response).

headers(Response) ->
    maps:get(headers, Response).

header(Name, Response) ->
    maps:get(normalize_header_name(Name), headers(Response), undefined).

body(Response) ->
    maps:get(body, Response).

document(Response) ->
    maps:get(document, Response, undefined).

url(Response) ->
    maps:get(url, Response).

method(Response) ->
    maps:get(method, Response).

request_headers(Response) ->
    maps:get(request_headers, Response, #{}).

cookies(Response) ->
    maps:get(cookies, Response, #{}).

meta(Response) ->
    maps:get(meta, Response, #{}).

css(Selector, Response) ->
    case document(Response) of
        undefined -> [];
        Doc -> scrapling_selector:css(Selector, Doc)
    end.

xpath(Selector, Response) ->
    case document(Response) of
        undefined -> [];
        Doc -> scrapling_selector:xpath(Selector, Doc)
    end.

normalize_header_list(Headers) when is_map(Headers) ->
    normalize_header_list(maps:to_list(Headers));
normalize_header_list(Headers) when is_list(Headers) ->
    [{normalize_header_name(Name), header_value(Value)} || {Name, Value} <- Headers].

headers_to_map(Headers) ->
    maps:from_list(Headers).

extract_cookies(Headers) ->
    lists:foldl(
      fun({Name, Value}, Acc) when Name =:= "set-cookie" ->
              merge_cookie(Value, Acc);
         (_, Acc) ->
              Acc
      end,
      #{},
      Headers).

merge_cookie(Value, Acc) ->
    [CookiePair | _] = string:split(Value, ";", all),
    case string:split(CookiePair, "=", leading) of
        [CookieName, CookieValue] ->
            Acc#{string:trim(CookieName) => string:trim(CookieValue)};
        _ ->
            Acc
    end.

maybe_document(Headers, Body) ->
    case is_html_response(Headers, Body) of
        true ->
            try scrapling_selector:from_html(Body) of
                Doc -> Doc
            catch
                _:_ -> undefined
            end;
        false ->
            undefined
    end.

is_html_response(Headers, Body) ->
    ContentType = lists:any(
      fun({Name, Value}) ->
          Name =:= "content-type" andalso contains_html(Value)
      end,
      Headers),
    ContentType orelse looks_like_html(Body).

contains_html(Value) ->
    Lower = string:lowercase(Value),
    lists:member($h, Lower) andalso lists:member($t, Lower) andalso lists:member($m, Lower) andalso lists:member($l, Lower).

looks_like_html(Body) ->
    Trimmed = string:trim(binary_to_list(to_binary(Body))),
    case Trimmed of
        [$< | _] -> true;
        _ -> false
    end.

normalize_header_name(Name) when is_atom(Name) ->
    string:lowercase(atom_to_list(Name));
normalize_header_name(Name) when is_binary(Name) ->
    string:lowercase(binary_to_list(Name));
normalize_header_name(Name) when is_list(Name) ->
    string:lowercase(Name).

header_value(Value) when is_binary(Value) ->
    binary_to_list(Value);
header_value(Value) when is_atom(Value) ->
    atom_to_list(Value);
header_value(Value) when is_integer(Value) ->
    integer_to_list(Value);
header_value(Value) when is_list(Value) ->
    Value.

method_value(Method) when is_atom(Method) ->
    list_to_binary(string:uppercase(atom_to_list(Method)));
method_value(Method) when is_binary(Method) ->
    list_to_binary(string:uppercase(binary_to_list(Method)));
method_value(Method) when is_list(Method) ->
    list_to_binary(string:uppercase(Method)).

to_binary(Value) when is_binary(Value) ->
    Value;
to_binary(Value) when is_list(Value) ->
    unicode:characters_to_binary(Value);
to_binary(Value) when is_atom(Value) ->
    atom_to_binary(Value, utf8);
to_binary(Value) when is_integer(Value) ->
    integer_to_binary(Value).
