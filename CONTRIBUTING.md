# Contributing

Trunk-based. Commit directly to `main`. No PRs.

## Build

```bash
rebar3 lint
rebar3 eunit      # a stand-in service through mcl_om over mem_macula
rebar3 dialyzer
```

## Style

- Erlang: `warnings_as_errors`, dialyzer clean.
- The harness stubs exactly the seam every mcl-* service resolves its pool
  and realm through. If mcl_om moves that seam, change it here, where the
  self-test goes red, not in the services.

## Releasing

Bump `vsn` in `src/mcl_testkit.app.src`, add the CHANGELOG entry, commit,
and push a `vX.Y.Z` tag. The `publish-hex` workflow publishes that tag; nobody
publishes by hand.

## Issues

https://github.com/macula-services/mcl-testkit/issues
