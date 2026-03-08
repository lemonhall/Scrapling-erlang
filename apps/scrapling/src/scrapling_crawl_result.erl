-module(scrapling_crawl_result).

-export([new/3, items/1, stats/1, completed/1]).

new(Items, Stats, Completed) ->
    #{items => Items, stats => Stats, completed => Completed}.

items(Result) ->
    maps:get(items, Result, []).

stats(Result) ->
    maps:get(stats, Result, #{}).

completed(Result) ->
    maps:get(completed, Result, false).
