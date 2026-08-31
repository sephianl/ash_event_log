defmodule AshEventLog.Resource do
  @moduledoc """
  Extension for resources that should log events.

      use Ash.Resource,
        extensions: [AshEventLog.Resource]

      event_log do
        event_log MyApp.Events.Event
        ignore_actions [:background_recalculate]
      end

  Use `only_actions` to opt in to a specific allowlist instead:

      event_log do
        event_log MyApp.Events.Event
        only_actions [:create, :update]
      end

  `ignore_actions` and `only_actions` are mutually exclusive.
  """

  @event_log %Spark.Dsl.Section{
    name: :event_log,
    no_depend_modules: [:event_log],
    schema: [
      event_log: [
        type: :atom,
        required: true,
        doc: "The event log resource module."
      ],
      ignore_actions: [
        type: {:list, :atom},
        default: [],
        doc: "Actions to exclude from event logging. Mutually exclusive with `only_actions`."
      ],
      only_actions: [
        type: {:list, :atom},
        doc:
          "If set, only these actions will be logged. Mutually exclusive with `ignore_actions`."
      ]
    ]
  }

  use Spark.Dsl.Extension,
    sections: [@event_log],
    transformers: [AshEventLog.Resource.Transformers.AddEventChange],
    verifiers: [AshEventLog.Resource.Verifiers.ValidateSinglePrimaryKey]
end
