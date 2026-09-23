%%% @doc Self-test: prove the harness lets an mcl-* service run its real
%%% publish/subscribe path over the in-memory mesh.
%%%
%%% `echo_service' is a stand-in for a real service: it resolves its pool the
%%% way every mcl-* service does (`mcl_om:macula_client()' and
%%% `mcl_om:realm()'), subscribes, and re-publishes. The harness publishes an
%%% input fact "from another node" and asserts the echoed output comes back,
%%% cross-pool, with no station.
-module(mcl_testkit_tests).
-include_lib("eunit/include/eunit.hrl").

echo_service_round_trip_test() ->
    mcl_testkit:with_mesh(fun(Mesh) ->
        Parent = self(),
        Svc = spawn_link(fun() -> echo_service(Parent) end),
        receive {ready, Svc} -> ok after 2000 -> erlang:error(service_not_ready) end,
        ok = mcl_testkit:subscribe(Mesh, <<"out">>),
        ok = mcl_testkit:publish(Mesh, <<"in">>, #{n => 1}),
        Got = mcl_testkit:await(<<"out">>, fun(P) -> maps:is_key(echoed, P) end),
        ?assertEqual(#{echoed => #{n => 1}}, Got)
    end).

%% The harness resolves a service pool and realm before any service boots,
%% through mcl_om's own facade, which is what services call.
identity_is_injected_test() ->
    mcl_testkit:with_mesh(fun(Mesh) ->
        ?assertEqual({ok, mcl_testkit:service_pool(Mesh)}, mcl_om:macula_client()),
        ?assertEqual({ok, mcl_testkit:realm(Mesh)}, mcl_om:realm())
    end).

%% A caller-chosen realm is the one the service sees.
the_realm_is_the_callers_test() ->
    Realm = <<7:256>>,
    mcl_testkit:with_mesh(#{realm => Realm}, fun(_Mesh) ->
        ?assertEqual({ok, Realm}, mcl_om:realm())
    end).

%% The stub is gone once the mesh is: a test after this one sees mcl_om's
%% real identity, not a leftover pool.
the_stub_is_removed_afterwards_test() ->
    mcl_testkit:with_mesh(fun(_Mesh) -> ok end),
    %% meck runs each mock as a process registered `<Module>_meck'.
    ?assertEqual(undefined, whereis(mcl_om_identity_meck)).

%% await gives up with the topic named, rather than hanging the suite.
await_times_out_naming_the_topic_test() ->
    mcl_testkit:with_mesh(fun(Mesh) ->
        ok = mcl_testkit:subscribe(Mesh, <<"silent">>),
        ?assertError({await_timeout, <<"silent">>},
                     mcl_testkit:await(<<"silent">>, fun(_) -> true end, 100))
    end).

%%--------------------------------------------------------------------

echo_service(Parent) ->
    {ok, Pool}  = mcl_om:macula_client(),
    {ok, Realm} = mcl_om:realm(),
    {ok, _Ref}  = macula:subscribe(Pool, Realm, <<"in">>, self()),
    Parent ! {ready, self()},
    echo_loop(Pool, Realm).

echo_loop(Pool, Realm) ->
    receive
        {macula_event, _Ref, <<"in">>, Payload, _Meta} ->
            _ = macula:publish(Pool, Realm, <<"out">>, #{echoed => Payload}),
            echo_loop(Pool, Realm)
    end.
