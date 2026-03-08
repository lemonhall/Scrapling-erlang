-module(scrapling_checkpoint).

-export([new/1, new/2, has_checkpoint/1, save/2, load/1, cleanup/1, checkpoint_path/1]).

new(Crawldir) ->
    new(Crawldir, 300.0).

new(Crawldir, Interval) when (is_integer(Interval) orelse is_float(Interval)) andalso Interval >= 0 ->
    Path = filename:join([to_list(Crawldir), "checkpoint.term"]),
    #{crawldir => to_list(Crawldir), interval => Interval, checkpoint_path => Path};
new(_Crawldir, Interval) when not (is_integer(Interval) orelse is_float(Interval)) ->
    erlang:error({invalid_checkpoint_interval_type, Interval});
new(_Crawldir, Interval) ->
    erlang:error({invalid_checkpoint_interval, Interval}).

checkpoint_path(Manager) ->
    maps:get(checkpoint_path, Manager).

has_checkpoint(Manager) ->
    filelib:is_regular(checkpoint_path(Manager)).

save(Manager, Data) ->
    Path = checkpoint_path(Manager),
    TempPath = Path ++ ".tmp",
    ok = filelib:ensure_dir(Path),
    ok = file:write_file(TempPath, term_to_binary(Data)),
    ok = file:rename(TempPath, Path).

load(Manager) ->
    case has_checkpoint(Manager) of
        false -> {error, checkpoint_not_found};
        true ->
            case file:read_file(checkpoint_path(Manager)) of
                {ok, Binary} -> {ok, binary_to_term(Binary)};
                Error -> Error
            end
    end.

cleanup(Manager) ->
    case has_checkpoint(Manager) of
        true -> file:delete(checkpoint_path(Manager));
        false -> ok
    end.

to_list(Value) when is_list(Value) ->
    Value;
to_list(Value) when is_binary(Value) ->
    binary_to_list(Value);
to_list(Value) when is_atom(Value) ->
    atom_to_list(Value).
