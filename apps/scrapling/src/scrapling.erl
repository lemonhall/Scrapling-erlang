-module(scrapling).

-export([version/0, info/0]).

-define(VSN, "0.1.0-dev").

version() ->
    ?VSN.

info() ->
    #{application => scrapling,
      stage => bootstrap,
      version => version(),
      otp_release => erlang:system_info(otp_release)}.
