defmodule AshEventLog.Test.Repo do
  use AshPostgres.Repo, otp_app: :ash_event_log

  def min_pg_version, do: %Version{major: 14, minor: 0, patch: 0}

  def installed_extensions, do: ["uuid-ossp", "ash-functions"]
end
