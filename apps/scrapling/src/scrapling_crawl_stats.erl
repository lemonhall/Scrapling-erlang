-module(scrapling_crawl_stats).

-export([new/0, requests_count/1, items_scraped/1, failed_requests_count/1, inc_requests/1, inc_items/1, inc_failed/1]).

new() ->
    #{requests_count => 0, items_scraped => 0, failed_requests_count => 0}.

requests_count(Stats) ->
    maps:get(requests_count, Stats, 0).

items_scraped(Stats) ->
    maps:get(items_scraped, Stats, 0).

failed_requests_count(Stats) ->
    maps:get(failed_requests_count, Stats, 0).

inc_requests(Stats) ->
    Stats#{requests_count => requests_count(Stats) + 1}.

inc_items(Stats) ->
    Stats#{items_scraped => items_scraped(Stats) + 1}.

inc_failed(Stats) ->
    Stats#{failed_requests_count => failed_requests_count(Stats) + 1}.
