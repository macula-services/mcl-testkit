# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - unreleased

Wire 1.0: the harness builds on the macula-15 `mcl_om` and the `macula_testkit`
release that answers wire 1.0's pool calls.

The major moves to 1.0 with the wire and not to 0.2.0, deliberately: every
service floats `mcl_om` at `~> 0.x` with no lockfile, so a 0.x on macula 15
would reach them on their next build. A 1.0 is one no `~> 0.x` resolves to, so
nothing moves onto the new wire until it is asked for by name.

### Added

- CI checks every Erlang block in the README and guides (`docs.yml`, macula-codebase-checks#8), on every change including doc-only ones, and `publish-hex.yml` waits on it.

### Changed

- `mcl_om` floor from `~> 0.27` to `~> 1.0`, the macula-15 line, and then to
  `~> 1.4` (macula-codebase-checks#4). 1.4.0 is the `mcl_om` whose base library
  is macula 16; `~> 1.0` also admits 1.3.0, and rebar3 drops a transitive
  conflict against a direct constraint without a word
  (macula-codebase-checks#14), which is how it once resolved 1.3.0 beside
  macula 16.0.0 and compiled.
- `macula_testkit` floor from `~> 0.1` to `~> 0.3`: 0.2.0 answers wire 1.0's
  registration wait and group-keyring ask with `{error, unsupported}`, which
  fails every `macula:subscribe` and crashes every publish over its pool.
- `macula` floor from `~> 12.1` to `~> 15.6`, and then to `~> 16.0`
  (macula-codebase-checks#4). Wire 1.0 is unchanged across 16.0, so the harness
  speaks to the same mesh; what 16.0 changes is the revocation bound
  (macula#118), which the harness neither issues nor gates.

## [0.1.0] - unreleased

The port of `hecate-testkit` onto `mcl_om` and `macula_testkit`.

### Added

- `with_mesh/1,2`: an in-memory two-pool mesh, with `mcl_om`'s identity
  stubbed so `mcl_om:macula_client/0` and `mcl_om:realm/0` answer the service
  pool and the test realm. The realm is the caller's choice.
- `boot_service/1,2`, `publish/3`, `subscribe/2`, `await/2,3` and the mesh
  readers.

### Changed from hecate-testkit

- `await` receives only its own topic's events. Events for other topics stay
  in the mailbox instead of being dropped unread.
- The stub is removed without a `catch`: it always exists by teardown.
