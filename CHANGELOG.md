# Changelog

## 0.1.5

Nothing here changes runtime behavior. The DSL's module-valued options stop creating compile-time
dependencies on the resources they name, and the package starts shipping the documentation and
agent rules it should have had from the first release.

### Fixed

- **Module options no longer create compile-time dependencies.** The `event_log` option in
  `AshEventLog.Resource` and the `destination` argument of `persist_actor_primary_key` in
  `AshEventLog.EventLog` are declared as `no_depend_modules`. Their aliases are still expanded,
  so nothing changes at runtime, but referencing a resource no longer compiles against it. This
  avoids compile-time dependency cycles — a tracked resource pointing at the event log resource,
  which points back at an actor resource — and stops unrelated resources from recompiling
  whenever the event log or an actor resource changes. It matches how Ash itself declares
  module-valued DSL options such as a relationship's `destination`.

### Added

- `usage-rules.md`, shipped in the package, so consumers can pull AshEventLog's rules into their
  agent instructions with `mix usage_rules.sync`.
- Generated DSL cheat sheets under `documentation/dsls/`, wired into the ExDoc output. Regenerate
  them with `mix spark.cheat_sheets`; `mix docs` does it for you.
- `.formatter.exs` exports `locals_without_parens` for the DSL. Consumers that add
  `:ash_event_log` to `import_deps` get `event_log` blocks formatted correctly instead of having
  parentheses inserted.
- A `LICENSE` file carrying the MIT text the package has always declared.

### Changed

- The published package no longer contains `priv/`. Every previous release shipped the test app's
  migrations and resource snapshots by accident.

## 0.1.4

### Fixed

- Atomic updates no longer log duplicate events.

## 0.1.3

### Added

- `only_actions` on the `event_log` section, an allowlist alternative to `ignore_actions`. The two
  are mutually exclusive.

## 0.1.2

### Fixed

- Primary keys implementing `String.Chars` are serialized correctly.

## 0.1.1

### Fixed

- Better handling of UUID primary keys when building an event's `record_id`.

## 0.1.0

### Added

- Initial release: the `AshEventLog.Resource` and `AshEventLog.EventLog` extensions, for automatic
  event logging and audit trails on Ash resources.
