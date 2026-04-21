defmodule AshEventLog.EventLog.Transformers.SetupEventLog do
  @moduledoc false
  use Spark.Dsl.Transformer

  alias Spark.Dsl.Transformer

  def transform(dsl_state) do
    pk_type = Transformer.get_option(dsl_state, [:event_log], :primary_key_type)
    record_id_type = Transformer.get_option(dsl_state, [:event_log], :record_id_type)
    public_fields = Transformer.get_option(dsl_state, [:event_log], :public_fields)
    actor_keys = Transformer.get_entities(dsl_state, [:event_log])

    dsl_state
    |> add_primary_key(pk_type, public_fields)
    |> add_attributes(record_id_type, public_fields)
    |> add_actor_attributes(actor_keys, public_fields)
    |> add_actions(actor_keys)
  end

  defp add_primary_key(dsl_state, pk_type, public_fields) do
    {type, default} = primary_key_config(pk_type)

    {:ok, attr} =
      Transformer.build_entity(Ash.Resource.Dsl, [:attributes], :attribute,
        name: :id,
        type: type,
        allow_nil?: false,
        primary_key?: true,
        writable?: false,
        default: default,
        public?: public?(:id, public_fields)
      )

    {:ok, Transformer.add_entity(dsl_state, [:attributes], attr)}
  end

  defp add_attributes({:ok, dsl_state}, record_id_type, public_fields) do
    attrs = [
      {:record_id, record_id_type, false, nil},
      {:resource, :string, false, nil},
      {:action, :string, false, nil},
      {:action_type, :string, false, nil},
      {:data, :map, false, %{}},
      {:metadata, :map, false, %{}},
      {:occurred_at, :utc_datetime_usec, false, nil}
    ]

    Enum.reduce(attrs, {:ok, dsl_state}, fn {name, type, allow_nil?, default}, {:ok, state} ->
      opts =
        [
          name: name,
          type: type,
          allow_nil?: allow_nil?,
          public?: public?(name, public_fields)
        ]
        |> maybe_add_default(default)

      {:ok, attr} = Transformer.build_entity(Ash.Resource.Dsl, [:attributes], :attribute, opts)
      {:ok, Transformer.add_entity(state, [:attributes], attr)}
    end)
  end

  defp add_actor_attributes({:ok, dsl_state}, actor_keys, public_fields) do
    Enum.reduce(actor_keys, {:ok, dsl_state}, fn actor_key, {:ok, state} ->
      {:ok, attr} =
        Transformer.build_entity(Ash.Resource.Dsl, [:attributes], :attribute,
          name: actor_key.name,
          type: actor_key.attribute_type,
          allow_nil?: actor_key.allow_nil?,
          public?: public?(actor_key.name, public_fields)
        )

      {:ok, Transformer.add_entity(state, [:attributes], attr)}
    end)
  end

  defp add_actions({:ok, dsl_state}, actor_keys) do
    accept_fields =
      [:record_id, :resource, :action, :action_type, :data, :metadata, :occurred_at] ++
        Enum.map(actor_keys, & &1.name)

    {:ok, create_action} =
      Transformer.build_entity(Ash.Resource.Dsl, [:actions], :create,
        name: :create,
        accept: accept_fields,
        primary?: true
      )

    {:ok, read_action} =
      Transformer.build_entity(Ash.Resource.Dsl, [:actions], :read,
        name: :read,
        primary?: true
      )

    dsl_state =
      dsl_state
      |> Transformer.add_entity([:actions], create_action)
      |> Transformer.add_entity([:actions], read_action)

    {:ok, dsl_state}
  end

  defp primary_key_config(:uuid),
    do: {:uuid, &Ash.UUID.generate/0}

  defp primary_key_config(:uuid_v7),
    do: {Ash.Type.UUIDv7, &Ash.UUIDv7.generate/0}

  defp primary_key_config(:integer),
    do: {:integer, nil}

  defp public?(_field, :all), do: true
  defp public?(field, fields) when is_list(fields), do: field in fields

  defp maybe_add_default(opts, nil), do: opts
  defp maybe_add_default(opts, default), do: Keyword.put(opts, :default, default)
end
