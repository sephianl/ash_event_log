defmodule AshEventLog.EventLog.Info do
  @moduledoc false

  def persist_actor_primary_keys(event_log_resource) do
    Spark.Dsl.Extension.get_entities(event_log_resource, [:event_log])
  end

  def logger_metadata_keys(event_log_resource) do
    Spark.Dsl.Extension.get_opt(
      event_log_resource,
      [:event_log],
      :logger_metadata_keys,
      [:request_id]
    )
  end
end
