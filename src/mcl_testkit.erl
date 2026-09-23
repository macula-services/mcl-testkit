%%% @doc Test harness: run an mcl-* service over an in-memory mesh.
%%%
%%% with_mesh/1 stands up a 2-pool mem_macula cluster and points the mcl_om
%%% identity at it, so any code that calls mcl_om:macula_client/0 and
%%% mcl_om:realm/0 (every service's publish/subscribe path) gets a SERVICE
%%% pool and a test realm, with no station, no QUIC and no certificate. The
%%% harness itself holds a second TEST pool on the same mesh, so it can
%%% publish facts "from another node" and assert what the service publishes
%%% back.
%%%
%%% The identity is stubbed with meck: mcl_om_identity has no setter, and
%%% mcl_om's facade delegates both calls to it.
-module(mcl_testkit).

-export([with_mesh/1, with_mesh/2]).
-export([boot_service/1, boot_service/2]).
-export([service_pool/1, test_pool/1, realm/1]).
-export([publish/3, subscribe/2, await/2, await/3]).

-type mesh() :: #{service_pool := pid(), test_pool := pid(),
                  realm := <<_:256>>, cluster := map()}.
-export_type([mesh/0]).

-define(DEFAULT_REALM, <<0:256>>).   %% 32 bytes; macula's guards need that
-define(DEFAULT_AWAIT_MS, 2000).

%% @doc Run Fun(Mesh) with the mcl_om mesh stubbed in memory, then tear down.
-spec with_mesh(fun((mesh()) -> Result)) -> Result.
with_mesh(Fun) ->
    with_mesh(#{}, Fun).

%% @doc As with_mesh/1. Opts: realm, the 32-byte realm tag the service sees.
-spec with_mesh(map(), fun((mesh()) -> Result)) -> Result.
with_mesh(Opts, Fun) when is_map(Opts), is_function(Fun, 1) ->
    Realm = maps:get(realm, Opts, ?DEFAULT_REALM),
    {ok, Cluster} = mem_macula:cluster(2),
    #{pools := [ServicePool, TestPool]} = Cluster,
    ok = inject_identity(ServicePool, Realm),
    Mesh = #{service_pool => ServicePool, test_pool => TestPool,
             realm => Realm, cluster => Cluster},
    try
        Fun(Mesh)
    after
        meck:unload(mcl_om_identity),
        mem_macula:stop(Cluster)
    end.

%% @doc Boot an mcl_om service under the stubbed mesh (call inside
%% with_mesh): starts the mcl_om application, boots the service through
%% mcl_om:boot/1, then starts any sibling OTP applications in Opts.apps (the
%% domain apps whose projections and process managers do the work).
-spec boot_service(module()) -> {ok, pid()}.
boot_service(ServiceMod) ->
    boot_service(ServiceMod, #{}).

-spec boot_service(module(), map()) -> {ok, pid()}.
boot_service(ServiceMod, Opts) when is_atom(ServiceMod), is_map(Opts) ->
    {ok, _} = application:ensure_all_started(mcl_om),
    {ok, SupPid} = mcl_om:boot(ServiceMod),
    _ = [{ok, _} = application:ensure_all_started(A) || A <- maps:get(apps, Opts, [])],
    {ok, SupPid}.

-spec service_pool(mesh()) -> pid().
service_pool(#{service_pool := P}) -> P.

-spec test_pool(mesh()) -> pid().
test_pool(#{test_pool := P}) -> P.

-spec realm(mesh()) -> <<_:256>>.
realm(#{realm := R}) -> R.

%% @doc Publish a fact as if from another node (through the test pool).
-spec publish(mesh(), binary(), term()) -> ok | {error, term()}.
publish(#{test_pool := Pool, realm := Realm}, Topic, Fact) ->
    macula:publish(Pool, Realm, Topic, Fact).

%% @doc Subscribe the calling process to Topic (through the test pool), so it
%% receives {macula_event, Ref, Topic, Payload, Meta}.
-spec subscribe(mesh(), binary()) -> ok.
subscribe(#{test_pool := Pool, realm := Realm}, Topic) ->
    {ok, _Ref} = macula:subscribe(Pool, Realm, Topic, self()),
    ok.

%% @doc Block until a fact for which MatchFun is true arrives on Topic (the
%% caller must have subscribed first). Returns the payload; raises
%% {await_timeout, Topic} after the default 2 seconds.
-spec await(binary(), fun((term()) -> boolean())) -> term().
await(Topic, MatchFun) ->
    await(Topic, MatchFun, ?DEFAULT_AWAIT_MS).

-spec await(binary(), fun((term()) -> boolean()), non_neg_integer()) -> term().
await(Topic, MatchFun, TimeoutMs) ->
    Deadline = erlang:monotonic_time(millisecond) + TimeoutMs,
    await_until(Topic, MatchFun, Deadline).

%%--------------------------------------------------------------------

inject_identity(Pool, Realm) ->
    ok = meck:new(mcl_om_identity, [passthrough]),
    ok = meck:expect(mcl_om_identity, macula_client, 0, {ok, Pool}),
    ok = meck:expect(mcl_om_identity, realm, 0, {ok, Realm}).

await_until(Topic, MatchFun, Deadline) ->
    Remaining = max(0, Deadline - erlang:monotonic_time(millisecond)),
    receive
        {macula_event, _Ref, Topic, Payload, _Meta} ->
            matched(MatchFun(Payload), Payload, Topic, MatchFun, Deadline)
    after Remaining ->
        erlang:error({await_timeout, Topic})
    end.

matched(true, Payload, _Topic, _MatchFun, _Deadline) -> Payload;
matched(false, _Payload, Topic, MatchFun, Deadline)  -> await_until(Topic, MatchFun, Deadline).
