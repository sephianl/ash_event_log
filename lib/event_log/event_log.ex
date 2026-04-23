defmodule AshEventLog.EventLog do
  @moduledoc """
  Extension for the centralized event log resource.

  Generates attributes, actions, and optionally actor fields.

      use Ash.Resource,
        extensions: [AshEventLog.EventLog]

      event_log do
        persist_actor_primary_key :user_id, MyApp.Accounts.User
        public_fields :all
      end
  """

  @persist_actor_primary_key %Spark.Dsl.Entity{
    name: :persist_actor_primary_key,
    args: [:name, :destination],
    target: AshEventLog.EventLog.PersistActorPrimaryKey,
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: "The attribute name for storing the actor's primary key (e.g. :user_id)"
      ],
      destination: [
        type: :atom,
        required: true,
        doc: "The actor resource module (e.g. MyApp.Accounts.User)"
      ],
      attribute_type: [
        type: :any,
        default: :uuid,
        doc: "The Ash type of the actor's primary key. Defaults to :uuid."
      ],
      allow_nil?: [
        type: :boolean,
        default: true,
        doc: "Whether this field can be nil."
      ]
    ]
  }

  @event_log %Spark.Dsl.Section{
    name: :event_log,
    entities: [@persist_actor_primary_key],
    schema: [
      primary_key_type: [
        type: {:one_of, [:uuid, :uuid_v7, :integer]},
        default: :uuid_v7,
        doc: "The type of the event's primary key."
      ],
      record_id_type: [
        type: {:one_of, [:uuid, :uuid_v7, :integer, :string]},
        default: :uuid,
        doc: "The type of the tracked resources' primary keys."
      ],
      public_fields: [
        type: {:or, [{:literal, :all}, {:list, :atom}]},
        default: [],
        doc: "Which fields to make public. `:all` or a list of field names."
      ],
      logger_metadata_keys: [
        type: {:list, :atom},
        default: [:request_id],
        doc:
          "Logger metadata keys to auto-capture into event metadata. Use `[:*]` to capture all."
      ]
    ]
  }

  use Spark.Dsl.Extension,
    sections: [@event_log],
    transformers: [AshEventLog.EventLog.Transformers.SetupEventLog]
end
