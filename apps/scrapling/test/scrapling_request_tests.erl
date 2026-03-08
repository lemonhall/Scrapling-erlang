-module(scrapling_request_tests).

-include_lib("eunit/include/eunit.hrl").

request_defaults_and_accessors_test() ->
    Request = scrapling_request:new("https://example.com/path?x=1"),
    ?assertEqual(<<"https://example.com/path?x=1">>, scrapling_request:url(Request)),
    ?assertEqual(<<>> , scrapling_request:sid(Request)),
    ?assertEqual(undefined, scrapling_request:callback(Request)),
    ?assertEqual(0, scrapling_request:priority(Request)),
    ?assertEqual(false, scrapling_request:dont_filter(Request)),
    ?assertEqual(#{}, scrapling_request:meta(Request)),
    ?assertEqual(<<"example.com">>, scrapling_request:domain(Request)).

request_copy_preserves_fields_test() ->
    Request = scrapling_request:new(
                "https://example.com/products",
                #{sid => "stealth",
                  priority => 5,
                  dont_filter => true,
                  meta => #{source => <<"seed">>},
                  callback => parse_product,
                  method => post,
                  body => <<"payload">>,
                  headers => #{<<"x-test">> => <<"1">>}}),
    Copy = scrapling_request:copy(Request),
    ?assertEqual(scrapling_request:url(Request), scrapling_request:url(Copy)),
    ?assertEqual(scrapling_request:sid(Request), scrapling_request:sid(Copy)),
    ?assertEqual(scrapling_request:callback(Request), scrapling_request:callback(Copy)),
    ?assertEqual(scrapling_request:priority(Request), scrapling_request:priority(Copy)),
    ?assertEqual(scrapling_request:dont_filter(Request), scrapling_request:dont_filter(Copy)),
    ?assertEqual(scrapling_request:meta(Request), scrapling_request:meta(Copy)),
    ?assertEqual(scrapling_request:session_opts(Request), scrapling_request:session_opts(Copy)).

request_fingerprint_stability_test() ->
    RequestOne = scrapling_request:new(
                   "https://example.com/products?page=1",
                   #{sid => "http", method => get}),
    RequestTwo = scrapling_request:new(
                   "https://example.com/products?page=1",
                   #{sid => "http", method => get}),
    RequestThree = scrapling_request:new(
                     "https://example.com/products?page=1",
                     #{sid => "stealth", method => get}),
    RequestFour = scrapling_request:new(
                    "https://example.com/products?page=1",
                    #{sid => "http", method => post, body => <<"payload">>}),
    ?assertEqual(scrapling_request:fingerprint(RequestOne), scrapling_request:fingerprint(RequestTwo)),
    ?assert(scrapling_request:fingerprint(RequestOne) =/= scrapling_request:fingerprint(RequestThree)),
    ?assert(scrapling_request:fingerprint(RequestOne) =/= scrapling_request:fingerprint(RequestFour)).
