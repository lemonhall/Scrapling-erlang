-module(scrapling_proxy_rotator).

-export([new/1, new/2, next/1, proxies/1, size/1]).

new(Proxies) ->
    new(Proxies, cyclic).

new([], _Strategy) ->
    erlang:error({invalid_proxy_rotator, empty_proxies});
new(Proxies, cyclic) when is_list(Proxies) ->
    #{proxies => Proxies, strategy => cyclic, index => 0};
new(Proxies, Strategy) when is_list(Proxies), is_function(Strategy, 2) ->
    #{proxies => Proxies, strategy => Strategy, index => 0}.

next(#{proxies := Proxies, strategy := cyclic, index := Index} = Rotator) ->
    Size = erlang:length(Proxies),
    CurrentIndex = Index rem Size,
    Proxy = lists:nth(CurrentIndex + 1, Proxies),
    {Proxy, Rotator#{index => (CurrentIndex + 1) rem Size}};
next(#{proxies := Proxies, strategy := Strategy, index := Index} = Rotator) when is_function(Strategy, 2) ->
    {Proxy, NextIndex} = Strategy(Proxies, Index),
    {Proxy, Rotator#{index => NextIndex}}.

proxies(Rotator) ->
    maps:get(proxies, Rotator).

size(Rotator) ->
    erlang:length(proxies(Rotator)).
