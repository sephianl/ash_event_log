# AshEventLog

Lightweight, centralized event logging for [Ash](https://ash-hq.org/) resources.

Inspired by [ash_events](https://hexdocs.pm/ash_events) and [ash_paper_trail](https://hexdocs.pm/ash_paper_trail), AshEventLog takes a different set of trade-offs:

- **Simpler than ash_events** — focused on audit logging only, with no event sourcing or replay. Less infrastructure to set up and maintain.
- **Easier to query than ash_paper_trail** — all events live in a single centralized table rather than per-resource version tables, making cross-resource queries straightforward.
- **Non-blocking** — events are written asynchronously after the action completes, so logging never slows down your writes.

## How it works

All create, update, and destroy actions across your tracked resources are automatically logged to a single events table. Each event records the resource, action, changed data, actor, and metadata.

## Usage

### 1. Define your event log resource

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
  end
end
```

### 2. Add tracking to your resources

```elixir
defmodule MyApp.Blog.Post do
  use Ash.Resource,
    extensions: [AshEventLog.Resource]

  event_log do
    event_log MyApp.Events.Event
    ignore_actions [:background_recalculate]
  end
end
```

That's it. All non-ignored actions on `Post` will now be logged to the `events` table.

## Installation

```elixir
def deps do
  [
    {:ash_event_log, "~> 0.1.0"}
  ]
end
```
