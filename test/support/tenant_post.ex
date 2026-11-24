defmodule AshEventLog.Test.TenantPost do
  @moduledoc """
  Tracked resource whose `create`/`update`/`destroy` actions are performed
  with an explicit `tenant`, used to verify that `CreateEvent` forwards that
  tenant when logging into a multitenant `AshEventLog.EventLog` resource.
  """
  use Ash.Resource,
    domain: AshEventLog.Test.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEventLog.Resource]

  postgres do
    table("tenant_posts")
    repo(AshEventLog.Test.Repo)
  end

  event_log do
    event_log(AshEventLog.Test.TenantEvent)
  end

  actions do
    defaults([:read, :destroy, create: [:title], update: [:title]])

    update :atomic_update do
      accept([:title])
      require_atomic?(true)
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:title, :string, allow_nil?: false, public?: true)
  end
end
