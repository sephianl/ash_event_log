defmodule AshEventLog.Test.TenantEvent do
  @moduledoc """
  Event log resource that itself requires a tenant, used to reproduce and
  guard against the multitenancy bug where `CreateEvent` created the event
  record without forwarding the tenant of the tracked action.
  """
  use Ash.Resource,
    domain: AshEventLog.Test.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEventLog.EventLog]

  postgres do
    table("tenant_events")
    repo(AshEventLog.Test.Repo)
  end

  multitenancy do
    strategy(:attribute)
    attribute(:tenant)
  end

  event_log do
    public_fields(:all)
  end

  attributes do
    attribute(:tenant, :string, allow_nil?: false, public?: true)
  end
end
