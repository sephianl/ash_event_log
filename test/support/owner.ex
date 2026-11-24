defmodule AshEventLog.Test.Owner do
  use Ash.Resource, domain: AshEventLog.Test.Domain

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, public?: true)
    attribute(:hashed_password, :string, sensitive?: true, public?: true)
    attribute(:joined_at, :utc_datetime_usec, public?: true)
  end

  relationships do
    belongs_to(:mentor, __MODULE__, public?: true)
  end
end
