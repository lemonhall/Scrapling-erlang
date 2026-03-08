-module(scrapling_storage).

-export([save/2, retrieve/1, reset/0]).

-define(TABLE, scrapling_storage_table).

save(Identifier, Data) ->
    ets:insert(table(), {Identifier, Data}),
    ok.

retrieve(Identifier) ->
    case ets:lookup(table(), Identifier) of
        [{_, Data}] -> Data;
        [] -> undefined
    end.

reset() ->
    case ets:info(?TABLE) of
        undefined -> ok;
        _ -> ets:delete_all_objects(?TABLE), ok
    end.

table() ->
    case ets:info(?TABLE) of
        undefined -> ets:new(?TABLE, [named_table, public, set]);
        _ -> ?TABLE
    end.
