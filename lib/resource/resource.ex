defmodule AshEventLog.Resource do
  @moduledoc """
  Extension for resources that should log events.

      use Ash.Resource,
        extensions: [AshEventLog.Resource]

      event_log do
        event_log MyApp.Events.Event
        ignore_actions [:background_recalculate]
      end
  """

  @event_log %Spark.Dsl.Section{
    name: :event_log,
    schema: [
      event_log: [
        type: :atom,
        required: true,
        doc: "The event log resource module."
      ],
      ignore_actions: [
        type: {:list, :atom},
        default: [],
        doc: "Actions to exclude from event logging."
      ]
    ]
  }

  use Spark.Dsl.Extension,
    sections: [@event_log],
    transformers: [AshEventLog.Resource.Transformers.AddEventChange]
end
