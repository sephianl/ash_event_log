defmodule AshEventLog.Test.User do
  use Ash.Resource,
    domain: AshEventLog.Test.Domain,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("users")
    repo(AshEventLog.Test.Repo)
  end

  actions do
    defaults([:read, create: [:name]])
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, allow_nil?: false, public?: true)
  end
end
