# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
