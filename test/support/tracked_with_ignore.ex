defmodule AshEventLog.Test.TrackedWithIgnore do
  use Ash.Resource,
    domain: AshEventLog.Test.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEventLog.Resource]

  postgres do
    table("tracked_items")
    repo(AshEventLog.Test.Repo)
  end

  event_log do
    event_log(AshEventLog.Test.Event)
    ignore_actions([:background_update])
  end

  actions do
    defaults([:read, :destroy, create: [:name], update: [:name]])

    update :background_update do
      accept([:name])
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, allow_nil?: false, public?: true)
  end
end
