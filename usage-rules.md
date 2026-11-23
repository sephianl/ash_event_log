# AshEventLog usage rules

AshEventLog writes an audit trail of every create, update, and destroy action to a single,
centralized event log resource. It is audit logging only — no event sourcing, no replay, no
per-resource version tables.

```elixir
defmodule MyApp.Blog.Post do
  use Ash.Resource,
    domain: MyApp.Blog,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEventLog.Resource]

  event_log do
    event_log MyApp.Events.Event
    ignore_actions [:background_recalculate]
  end
end
```

## There are two extensions and they are not interchangeable

| Extension | Goes on | Purpose |
|---|---|---|
| `AshEventLog.EventLog` | The one central event resource | Generates the event schema and actions |
| `AshEventLog.Resource` | Each resource you want audited | Hooks actions to write events |

Both extensions define a DSL section named `event_log`, but the options inside differ
completely. Check which extension a resource uses before writing the section.

## Setting up the event log resource

```elixir
defmodule MyApp.Events.Event do
  use Ash.Resource,
    domain: MyApp.Events,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEventLog.EventLog]

  postgres do
    table "events"
    repo MyApp.Repo
  end

  event_log do
    persist_actor_primary_key :user_id, MyApp.Accounts.User
    public_fields :all
  end
end
```

### Do not hand-write the schema

The extension generates all of these. Defining them yourself is a compile error or a
silent conflict:

- **Attributes**: `id`, `record_id`, `resource`, `action`, `action_type`, `data`,
  `metadata`, `occurred_at`, plus one attribute per `persist_actor_primary_key`.
- **Actions**: a primary `:create` (accepting the fields above) and a primary `:read`.

Add your own actions under different names if you need them (e.g. a `:by_resource`
read), but do not redefine `:create` or `:read`.

### Options

- `primary_key_type` — `:uuid_v7` (default), `:uuid`, or `:integer`.
- `record_id_type` — the type of the *tracked* resources' primary keys. Defaults to
  `:uuid`. If you track resources with differently-typed primary keys, use `:string`.
- `public_fields` — defaults to `[]`, meaning **every generated attribute is private**.
  Set `:all` or a list of field names before exposing events over AshJsonApi,
  AshGraphql, or anything else that respects `public?`.
- `logger_metadata_keys` — defaults to `[:request_id]`. Use `[:*]` to capture all
  Logger metadata (actor key names are excluded to avoid collisions).

### Actors

```elixir
persist_actor_primary_key :user_id, MyApp.Accounts.User
persist_actor_primary_key :admin_id, MyApp.Accounts.Admin, attribute_type: :integer
```

- The actor is matched **by struct type**. An event only fills in `:user_id` when the
  action's actor is a `%MyApp.Accounts.User{}`. A non-struct actor (a map, a plain id)
  records no actor at all.
- Declare one `persist_actor_primary_key` per actor resource. All of them are nullable
  by default, which is what you want when several actor types can act.
- `attribute_type` defaults to `:uuid`. Set it explicitly if the actor's primary key is
  an integer or a UUIDv7.

## Tracking a resource

Add `AshEventLog.Resource` and point it at the event log, as in the example at the top.

- `event_log` (required) — the module of the event log resource.
- `ignore_actions` — a denylist. Everything else is logged.
- `only_actions` — an allowlist. Only these actions are logged.
- **`ignore_actions` and `only_actions` are mutually exclusive.** Setting both raises a
  `Spark.Error.DslError` at compile time.

Constraints:

- Only `:create`, `:update`, and `:destroy` actions are logged. Reads are never logged.
- The tracked resource **must have a single-column primary key**. A composite primary
  key fails verification at compile time.

## Behavior you need to know about

### Logging is asynchronous and fire-and-forget

Events are written after the action succeeds, in a separate process spawned with
`spawn/1` (deliberately not `Task.start/1`, so the event write does not inherit the
caller's database connection). This means:

- A failed event write **never fails the action**. It is reported via `Logger.error`.
- The event may not exist yet when the action returns.

In tests, set `config :ash, :disable_async?, true` to make event writes synchronous.
Without it, assertions on the event log are racy.

### Events are written without authorization

The event log's `:create` action is always called with `authorize?: false`. Do not rely
on policies to filter what gets written; use `ignore_actions` / `only_actions` instead.

### What lands in `data`

`data` merges the changeset's changed attributes, atomic updates (resolved to their
post-action values), and action arguments.

- **Anything marked `sensitive?` is excluded** — attributes and arguments both.
- **A record is stored as its non-sensitive attributes only**, wherever it appears: a
  `:struct` argument (with or without `instance_of`), a list of records, or a record nested
  in a map. Its relationships, calculations, aggregates and metadata never land in `data`.
- Values are dumped with `Ash.Type.dump_to_embedded/3` and then made JSON-safe. Dates and
  times (`DateTime`, `NaiveDateTime`, `Date`, `Time`) become ISO 8601 strings, other structs
  become maps, tuples become lists, PIDs and references become strings. The same holds for
  `metadata`.
- `record_id` is always stored as a string.

### Attaching custom metadata

Put a map under the `:ash_event_log_metadata` context key:

```elixir
post
|> Ash.Changeset.for_update(:update, params)
|> Ash.Changeset.set_context(%{ash_event_log_metadata: %{reason: "moderation"}})
|> Ash.update!(actor: current_user)
```

Explicit metadata is merged over the captured Logger metadata, so it wins on conflict.

## Common mistakes

- Writing `AshEventLog.EventLog`'s options (`public_fields`, `primary_key_type`) inside
  a tracked resource's `event_log` block, or vice versa.
- Defining `record_id`/`data`/`metadata` attributes by hand on the event resource.
- Querying events in a test without `config :ash, :disable_async?, true`.
- Exposing the event resource over an API and finding every field missing — set
  `public_fields`.
- Expecting a `record_id_type` of `:uuid` to hold the primary keys of a resource with
  integer or string ids. Match the type, or use `:string`.
- Adding both `ignore_actions` and `only_actions`.
