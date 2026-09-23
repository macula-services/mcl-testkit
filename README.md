# mcl-testkit

A test harness for **mcl-\*** services. It runs a service's real mesh path
(`mcl_om:macula_client/0`, `mcl_om:realm/0`, `macula:publish/subscribe`) over
an in-memory macula mesh, with no station, no QUIC and no certificate.

It composes [`macula_testkit`](https://github.com/macula-io/macula-testkit)'s
loopback pools into the `mcl_om` identity. `with_mesh/1` stands up a two-pool
cluster and stubs the identity (with meck), so the service resolves the
SERVICE pool and a test realm. The harness keeps the second, TEST pool: it
publishes facts "from another node" and asserts on what the service publishes
back.

```erlang
echo_round_trip_test() ->
    mcl_testkit:with_mesh(fun(Mesh) ->
        {ok, _} = mcl_testkit:boot_service(my_service),
        ok = mcl_testkit:subscribe(Mesh, <<"out">>),
        ok = mcl_testkit:publish(Mesh, <<"in">>, #{n => 1}),
        #{echoed := _} = mcl_testkit:await(<<"out">>, fun(P) -> maps:is_key(echoed, P) end)
    end).
```

## Install

As a test dependency:

```erlang
{profiles, [{test, [{deps, [{mcl_testkit, "~> 0.1"}]}]}]}.
```

## API

| Function | What it does |
|---|---|
| `with_mesh(Fun)`, `with_mesh(#{realm => R}, Fun)` | Runs `Fun(Mesh)` on a fresh in-memory mesh, then removes the stub and stops the cluster. The realm defaults to 32 zero bytes. |
| `boot_service(Mod)`, `boot_service(Mod, #{apps => [...]})` | Starts `mcl_om`, boots `Mod` through `mcl_om:boot/1`, then starts the listed sibling applications. |
| `publish(Mesh, Topic, Fact)` | Publishes from the TEST pool, as another node would. |
| `subscribe(Mesh, Topic)` | Subscribes the calling process through the TEST pool. |
| `await(Topic, Match)`, `await(Topic, Match, Ms)` | Waits for a fact on `Topic` that `Match` accepts. Raises `{await_timeout, Topic}` after 2 s by default. Events for other topics stay in the mailbox. |
| `service_pool/1`, `test_pool/1`, `realm/1` | Read the mesh. |

Pub/sub only, like `macula_testkit`: RPC and advertise are not simulated.

## Licence

Apache-2.0. See [LICENSE](LICENSE).
