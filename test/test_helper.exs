{:ok, _} = AshEventLog.Test.Repo.start_link()
ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(AshEventLog.Test.Repo, :manual)
