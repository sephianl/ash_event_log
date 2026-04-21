import Config

config :ash_event_log,
  ash_domains: [AshEventLog.Test.Domain],
  ecto_repos: [AshEventLog.Test.Repo]

config :ash_event_log, AshEventLog.Test.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "ash_event_log_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  socket_dir: System.get_env("PGHOST")

config :ash, :disable_async?, true

config :logger, level: :warning
