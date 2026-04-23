defmodule AshEventLog.Test.CompositePkStub do
  @moduledoc false
  use Ash.Resource,
    domain: AshEventLog.Test.Domain,
    data_layer: :embedded

  attributes do
    attribute(:org_id, :uuid, allow_nil?: false, primary_key?: true, public?: true)
    attribute(:item_id, :uuid, allow_nil?: false, primary_key?: true, public?: true)
  end

  actions do
    defaults([:read, create: [:org_id, :item_id]])
  end
end
