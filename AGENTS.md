# AshEventLog — Ash Audit Logging Extension

A hex package providing two Ash/Spark extensions that write an audit trail of every create, update, and destroy action to a single centralized event log resource.

It is **audit logging only**. There is no event sourcing, no replay, no per-resource version tables. If a request sounds like "replay events to rebuild state", that is `ash_events`, not this. Don't build toward it here.

- **Two extensions, not interchangeable**: `AshEventLog.EventLog` goes on the one central event resource and generates its schema/actions; `AshEventLog.Resource` goes on each audited resource and hooks its actions
- **Both define a DSL section named `event_log`** with completely different options inside. Check which extension a resource uses before touching the section
- **`usage-rules.md` is the user-facing contract.** It documents the behavior consumers rely on — read it before changing semantics, update it when semantics change, and treat a change that makes it wrong as a breaking change

## Environment

`mix` is NOT on the PATH, and the test suite needs postgres:

```bash
devenv processes up -d            # start postgres first
devenv shell -- mix test          # or `devenv shell` for an interactive session
devenv processes down
```

Skipping `devenv processes up -d` gives `Postgrex.Protocol ... :enoent` and `Setup failed`. That is a missing database, not broken code.

## Regenerate after any DSL change

There is no CI, so nothing catches drift. Adding, renaming, or changing the arity of a DSL option or entity invalidates two committed files that also ship in the package:

```bash
devenv shell -- mix spark.formatter      # .formatter.exs
devenv shell -- mix spark.cheat_sheets   # documentation/dsls/*.md
devenv shell -- mix docs                 # runs cheat_sheets + docs + replace_doc_links
```

A stale `.formatter.exs` breaks formatting for every consumer that adds `:ash_event_log` to `import_deps`.

## Testing

- `devenv shell -- mix test 2>&1 | tail -20` for pass/fail; read more only when diagnosing
- `devenv shell -- mix format --check-formatted` before presenting a diff
- Test resources live in `test/support/`. Changing their attributes requires `mix ash_postgres.generate_migrations --name <change>` — commit both `priv/repo/migrations` and `priv/resource_snapshots`
- `config :ash, :disable_async?, true` in `config/config.exs` makes event writes synchronous. Event writes are async in production, so without it every event assertion is racy. Do not remove it

## Architecture

```
lib/event_log/          AshEventLog.EventLog — the central log resource
  event_log.ex            DSL: primary_key_type, record_id_type, public_fields,
                          logger_metadata_keys, persist_actor_primary_key entities
  transformers/           SetupEventLog generates all attributes + :create/:read actions
  info.ex                 Introspection helpers

lib/resource/           AshEventLog.Resource — audited resources
  resource.ex             DSL: event_log, ignore_actions, only_actions
  transformers/           AddEventChange attaches the change to create/update/destroy
  verifiers/              ValidateSinglePrimaryKey
  changes/create_event.ex The actual event writing
```

`create_event.ex` is where the subtlety lives. Read the comment in `atomic/3` before touching any hook — the atomic and batch paths each cover their cases exactly once, and adding an `after_action` in the wrong place double-logs.

## Key conventions

- **Module-valued DSL options need `no_depend_modules`.** Any option holding a resource module (`event_log`, `destination`) must be listed, or referencing a resource creates a compile-time dependency on it and risks cycles. This is how Ash declares relationship `destination`
- Event writes always use `authorize?: false` — filtering belongs in `ignore_actions`/`only_actions`, not policies
- Event writes use `spawn/1`, deliberately not `Task.start/1`, to avoid inheriting the caller's DB connection via `$callers`
- A failed event write must never fail the action. Log it and move on
- Sensitive attributes and arguments are excluded from `data`. Keep it that way
- Generated attributes default to `public?: false` unless `public_fields` says otherwise

## Code style

- No inline comments explaining what code does — the exception is non-obvious *why*, like the `atomic/3` comment
- Pattern match on function heads, not `case` in the body
- Extract helpers early; keep nesting shallow

## Releasing

1. Bump `@version` in `mix.exs`
2. Add a `## x.y.z` section to `CHANGELOG.md` — prose paragraph framing the release, then `### Fixed` / `### Added` / `### Changed`
3. Regenerate cheat sheets if the DSL moved
4. `mix hex.build --unpack -o /tmp/pkg` and check the file list before publishing

Copyright holder is **Sephia**.
