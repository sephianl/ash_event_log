defmodule AshEventLog.EventLog.Info do
  @moduledoc false

  def persist_actor_primary_keys(event_log_resource) do
    Spark.Dsl.Extension.get_entities(event_log_resource, [:event_log])
  end
end
