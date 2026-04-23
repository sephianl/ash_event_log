defmodule AshEventLog.EventLog.PersistActorPrimaryKey do
  @moduledoc false
  defstruct [:name, :destination, :__spark_metadata__, attribute_type: :uuid, allow_nil?: true]
end
