-module(scrapling_test_httpd).

-export([start_link/1, stop/1]).

start_link(Handler) when is_function(Handler, 1) ->
    Parent = self(),
    Pid = spawn(fun() -> init(Parent, Handler) end),
    receive
        {httpd_started, Pid, Port} ->
            {ok, Pid, "http://127.0.0.1:" ++ integer_to_list(Port)}
    after 2000 ->
        erlang:error(httpd_start_timeout)
    end.

stop(Pid) ->
    Ref = monitor(process, Pid),
    Pid ! stop,
    receive
        {'DOWN', Ref, process, Pid, _Reason} -> ok
    after 2000 ->
        erlang:error(httpd_stop_timeout)
    end.

init(Parent, Handler) ->
    {ok, Listen} = gen_tcp:listen(0, [binary, {packet, raw}, {active, false}, {reuseaddr, true}, {ip, {127,0,0,1}}]),
    {ok, {_Addr, Port}} = inet:sockname(Listen),
    Parent ! {httpd_started, self(), Port},
    loop(Listen, Handler).

loop(Listen, Handler) ->
    receive
        stop ->
            ok = gen_tcp:close(Listen)
    after 0 ->
        case gen_tcp:accept(Listen, 100) of
            {ok, Socket} ->
                ok = handle_socket(Socket, Handler),
                loop(Listen, Handler);
            {error, timeout} ->
                loop(Listen, Handler);
            {error, closed} ->
                ok
        end
    end.

handle_socket(Socket, Handler) ->
    {ok, Request} = recv_request(Socket),
    Response = Handler(Request),
    ok = gen_tcp:send(Socket, encode_response(Response)),
    ok = gen_tcp:close(Socket).

recv_request(Socket) ->
    {ok, HeaderBin, Rest} = recv_until_headers(Socket, <<>>),
    Request0 = parse_request(HeaderBin, <<>>),
    ContentLength = maps:get(content_length, Request0),
    Body = recv_body(Socket, Rest, ContentLength),
    {ok, Request0#{body => Body}}.

recv_until_headers(Socket, Acc) ->
    case binary:match(Acc, <<"\r\n\r\n">>) of
        {Position, _Length} ->
            HeaderLength = Position + 4,
            <<HeaderBin:HeaderLength/binary, Rest/binary>> = Acc,
            {ok, HeaderBin, Rest};
        nomatch ->
            case gen_tcp:recv(Socket, 0, 2000) of
                {ok, Chunk} -> recv_until_headers(Socket, <<Acc/binary, Chunk/binary>>);
                Error -> Error
            end
    end.

recv_body(_Socket, Rest, ContentLength) when byte_size(Rest) >= ContentLength ->
    <<Body:ContentLength/binary, _/binary>> = Rest,
    Body;
recv_body(Socket, Rest, ContentLength) ->
    Missing = ContentLength - byte_size(Rest),
    case gen_tcp:recv(Socket, Missing, 2000) of
        {ok, Chunk} -> recv_body(Socket, <<Rest/binary, Chunk/binary>>, ContentLength);
        {error, closed} when ContentLength =:= 0 -> <<>>
    end.

parse_request(HeaderBin, Body) ->
    [RequestLine | HeaderLines] = string:split(binary_to_list(HeaderBin), "\r\n", all),
    [Method, Target, _Version] = string:split(RequestLine, " ", all),
    Headers = parse_headers(HeaderLines, #{}),
    #{method => Method,
      target => Target,
      path => request_path(Target),
      headers => Headers,
      content_length => content_length(Headers),
      body => Body}.

parse_headers([], Acc) ->
    Acc;
parse_headers([[] | _], Acc) ->
    Acc;
parse_headers([Line | Rest], Acc) ->
    case string:split(Line, ":", leading) of
        [Name, Value] ->
            parse_headers(Rest, Acc#{string:lowercase(string:trim(Name)) => string:trim(Value)});
        _ ->
            parse_headers(Rest, Acc)
    end.

content_length(Headers) ->
    case maps:get("content-length", Headers, undefined) of
        undefined -> 0;
        Value -> list_to_integer(Value)
    end.

request_path(Target) ->
    Parsed = uri_string:parse(Target),
    case maps:get(path, Parsed, undefined) of
        undefined ->
            case string:split(Target, "?", all) of
                [Path | _] when Path =/= [] -> Path;
                _ -> "/"
            end;
        [] -> "/";
        Path -> Path
    end.

encode_response(Response) ->
    Status = maps:get(status, Response, 200),
    Body = to_binary(maps:get(body, Response, <<>>)),
    Headers = maps:get(headers, Response, []),
    NormalizedHeaders = [{normalize_header_name(Name), to_list(Value)} || {Name, Value} <- Headers],
    HeaderLines = [
        "HTTP/1.1 ", integer_to_list(Status), " ", reason_phrase(Status), "\r\n",
        [header_line(Name, Value) || {Name, Value} <- NormalizedHeaders],
        header_line("content-length", integer_to_list(byte_size(Body))),
        header_line("connection", "close"),
        "\r\n"
    ],
    iolist_to_binary([HeaderLines, Body]).

header_line(Name, Value) ->
    [Name, ": ", Value, "\r\n"].

reason_phrase(200) -> "OK";
reason_phrase(404) -> "Not Found";
reason_phrase(500) -> "Internal Server Error";
reason_phrase(_) -> "OK".

normalize_header_name(Name) when is_atom(Name) ->
    string:lowercase(atom_to_list(Name));
normalize_header_name(Name) when is_binary(Name) ->
    string:lowercase(binary_to_list(Name));
normalize_header_name(Name) when is_list(Name) ->
    string:lowercase(Name).

to_binary(Value) when is_binary(Value) ->
    Value;
to_binary(Value) when is_list(Value) ->
    unicode:characters_to_binary(Value).

to_list(Value) when is_list(Value) ->
    Value;
to_list(Value) when is_binary(Value) ->
    binary_to_list(Value);
to_list(Value) when is_integer(Value) ->
    integer_to_list(Value).
