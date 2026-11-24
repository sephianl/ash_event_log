defmodule AshEventLog.Test.PostSettings do
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute(:theme, :string, public?: true)
    attribute(:api_key, :string, sensitive?: true, public?: true)
  end
end
