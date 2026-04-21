defmodule AshEventLog.Test.Event do
  use Ash.Resource,
    domain: AshEventLog.Test.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEventLog.EventLog]

  postgres do
    table "events"
    repo AshEventLog.Test.Repo
  end

  event_log do
    public_fields :all
  end
end
