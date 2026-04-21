defmodule AshEventLog.Resource.Transformers.AddEventChange do
  @moduledoc false
  use Spark.Dsl.Transformer

  alias Spark.Dsl.Transformer

  def transform(dsl_state) do
    event_log = Transformer.get_option(dsl_state, [:event_log], :event_log)
    ignore_actions = Transformer.get_option(dsl_state, [:event_log], :ignore_actions) || []

    case Transformer.build_entity(Ash.Resource.Dsl, [:changes], :change,
           change:
             {AshEventLog.Resource.Changes.CreateEvent,
              event_log: event_log, ignore_actions: ignore_actions},
           on: [:create, :update, :destroy]
         ) do
      {:ok, change} ->
        {:ok, Transformer.add_entity(dsl_state, [:changes], change, type: :append)}

      other ->
        other
    end
  end
end
