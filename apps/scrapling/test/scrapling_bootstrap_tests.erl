-module(scrapling_bootstrap_tests).

-include_lib("eunit/include/eunit.hrl").

bootstrap_facade_exports_test() ->
    ?assertEqual(ok, application:load(scrapling)),
    ?assertMatch({module, scrapling}, code:ensure_loaded(scrapling)),
    ?assert(erlang:function_exported(scrapling, version, 0)),
    ?assert(erlang:function_exported(scrapling, info, 0)).
