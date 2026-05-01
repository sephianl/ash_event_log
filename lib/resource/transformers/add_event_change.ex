defmodule AshEventLog.Resource.Transformers.AddEventChange do
  @moduledoc false
  use Spark.Dsl.Transformer

  alias Spark.Dsl.Transformer

  def transform(dsl_state) do
    event_log = Transformer.get_option(dsl_state, [:event_log], :event_log)
    ignore_actions = Transformer.get_option(dsl_state, [:event_log], :ignore_actions)
    only_actions = Transformer.get_option(dsl_state, [:event_log], :only_actions)

    with :ok <- validate_mutually_exclusive(ignore_actions, only_actions),
         {:ok, change} <-
           Transformer.build_entity(Ash.Resource.Dsl, [:changes], :change,
             change:
               {AshEventLog.Resource.Changes.CreateEvent,
                event_log: event_log, ignore_actions: ignore_actions, only_actions: only_actions},
             on: [:create, :update, :destroy]
           ) do
      {:ok, Transformer.add_entity(dsl_state, [:changes], change, type: :append)}
    end
  end

  defp validate_mutually_exclusive(ignore_actions, only_actions)
       when is_list(only_actions) and ignore_actions not in [nil, []] do
    {:error,
     Spark.Error.DslError.exception(
       path: [:event_log],
       message: "`ignore_actions` and `only_actions` are mutually exclusive. Specify only one."
     )}
  end

  defp validate_mutually_exclusive(_ignore_actions, _only_actions), do: :ok
end
