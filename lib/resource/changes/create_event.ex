defmodule AshEventLog.Resource.Changes.CreateEvent do
  @moduledoc false
  use Ash.Resource.Change

  require Logger

  @impl true
  def change(changeset, opts, context) do
    if changeset.action.name in opts[:ignore_actions] do
      changeset
    else
      event_log = opts[:event_log]

      Ash.Changeset.after_action(changeset, fn changeset, result ->
        params = build_event_params(changeset, result, event_log, context)
        log_event(event_log, params)
        {:ok, result}
      end)
    end
  end

  @impl true
  def atomic(changeset, opts, context) do
    if changeset.action.name in opts[:ignore_actions] do
      {:ok, changeset}
    else
      event_log = opts[:event_log]

      {:ok,
       Ash.Changeset.after_action(changeset, fn changeset, result ->
         params = build_event_params(changeset, result, event_log, context)
         log_event(event_log, params)
         {:ok, result}
       end)}
    end
  end

  @impl true
  def batch_change(changesets, _opts, _context), do: changesets

  @impl true
  def after_batch(changesets_and_results, opts, context) do
    event_log = opts[:event_log]
    ignore_actions = opts[:ignore_actions]

    events =
      changesets_and_results
      |> Enum.reject(fn {cs, _} -> cs.action.name in ignore_actions end)
      |> Enum.map(fn {cs, result} -> build_event_params(cs, result, event_log, context) end)

    if events != [], do: log_events_bulk(events, event_log)

    Enum.map(changesets_and_results, fn {_, result} -> {:ok, result} end)
  end

  defp log_event(event_log, params) do
    run_async(fn ->
      try do
        case create_event(event_log, params) do
          {:ok, _} ->
            :ok

          {:error, error} ->
            Logger.error("AshEventLog: failed to create event: #{inspect(error)}")
        end
      rescue
        e ->
          Logger.error("AshEventLog: failed to create event: #{inspect(e)}")
      end
    end)
  end

  defp log_events_bulk(events, event_log) do
    run_async(fn ->
      try do
        result =
          Ash.bulk_create(events, event_log, :create,
            authorize?: false,
            return_errors?: true
          )

        if result.error_count > 0 do
          Logger.error(
            "AshEventLog: failed to create #{result.error_count} event(s): #{inspect(result.errors)}"
          )
        end
      rescue
        e ->
          Logger.error("AshEventLog: failed to create event(s): #{inspect(e)}")
      end
    end)
  end

  defp run_async(fun) do
    if Application.get_env(:ash, :disable_async?) do
      fun.()
    else
      # Use spawn (not Task.start) to avoid inheriting the caller's
      # DB connection via $callers. Event logging should use its own
      # connection from the pool for full isolation.
      spawn(fun)
    end
  end

  defp create_event(event_log, params) do
    event_log
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create(authorize?: false)
  end

  defp build_event_params(changeset, result, event_log, context) do
    actor_params = build_actor_params(event_log, Map.get(context, :actor))

    Map.merge(
      %{
        record_id: get_record_id(changeset, result),
        resource: inspect(changeset.resource),
        action: to_string(changeset.action.name),
        action_type: to_string(changeset.action_type),
        data: extract_data(changeset, result),
        metadata: build_metadata(changeset, event_log),
        occurred_at: DateTime.utc_now()
      },
      actor_params
    )
  end

  defp build_metadata(changeset, event_log) do
    logger_meta = capture_logger_metadata(event_log)
    explicit_meta = Map.get(changeset.context, :ash_event_log_metadata, %{})
    Map.merge(logger_meta, explicit_meta) |> json_safe()
  end

  defp capture_logger_metadata(event_log) do
    keys = AshEventLog.EventLog.Info.logger_metadata_keys(event_log)

    case keys do
      [:*] ->
        actor_keys =
          event_log
          |> AshEventLog.EventLog.Info.persist_actor_primary_keys()
          |> Enum.map(& &1.name)

        Logger.metadata() |> Keyword.drop(actor_keys) |> Map.new()

      keys ->
        Logger.metadata() |> Keyword.take(keys) |> Map.new()
    end
  end

  defp build_actor_params(_event_log, actor) when not is_struct(actor), do: %{}

  defp build_actor_params(event_log, actor) do
    event_log
    |> AshEventLog.EventLog.Info.persist_actor_primary_keys()
    |> Enum.reduce(%{}, fn config, acc ->
      if is_struct(actor, config.destination) do
        [pk_field] = Ash.Resource.Info.primary_key(actor.__struct__)
        Map.put(acc, config.name, Map.get(actor, pk_field))
      else
        acc
      end
    end)
  end

  defp get_record_id(changeset, result) do
    [pk] = Ash.Resource.Info.primary_key(changeset.resource)

    id =
      case changeset.action_type do
        :create ->
          Map.get(result, pk)

        _ ->
          # In atomic mode, changeset.data may not be a loaded record,
          # so fall back to result which always has the PK
          case changeset.data do
            %{^pk => id} when not is_nil(id) -> id
            _ -> Map.get(result, pk)
          end
      end

    if id, do: to_string(id)
  end

  defp extract_data(changeset, result) do
    attr_data =
      Enum.reduce(changeset.attributes, %{}, fn {key, value}, acc ->
        attr = Ash.Resource.Info.attribute(changeset.resource, key)

        if attr && not attr.sensitive? do
          Map.put(acc, key, dump_value(value, attr))
        else
          acc
        end
      end)

    atomic_data =
      Enum.reduce(changeset.atomics, %{}, fn {key, _expr}, acc ->
        attr = Ash.Resource.Info.attribute(changeset.resource, key)

        if attr && not attr.sensitive? do
          Map.put(acc, key, dump_value(Map.get(result, key), attr))
        else
          acc
        end
      end)

    arg_data =
      Enum.reduce(changeset.arguments, %{}, fn {key, value}, acc ->
        arg = Enum.find(changeset.action.arguments, &(&1.name == key))

        if arg && not arg.sensitive? do
          Map.put(acc, key, dump_value(value, arg))
        else
          acc
        end
      end)

    attr_data |> Map.merge(atomic_data) |> Map.merge(arg_data) |> json_safe()
  end

  defp dump_value(value, %{type: type, constraints: constraints}) do
    case Ash.Type.dump_to_embedded(type, value, constraints || []) do
      {:ok, dumped} -> dumped
      _ -> value
    end
  rescue
    _e in [ArgumentError, FunctionClauseError] -> value
  end

  defp json_safe(value) when is_binary(value) do
    if String.printable?(value) do
      value
    else
      case Ecto.UUID.load(value) do
        {:ok, uuid_string} -> uuid_string
        :error -> inspect(value)
      end
    end
  end

  defp json_safe(value) when is_map(value) and not is_struct(value) do
    Map.new(value, fn {k, v} -> {json_safe_key(k), json_safe(v)} end)
  end

  defp json_safe(value) when is_tuple(value), do: value |> Tuple.to_list() |> json_safe()
  defp json_safe(value) when is_list(value), do: Enum.map(value, &json_safe/1)
  defp json_safe(%_{} = value), do: json_safe(Map.from_struct(value))
  defp json_safe(value) when is_pid(value) or is_reference(value), do: inspect(value)
  defp json_safe(value), do: value

  defp json_safe_key(key) when is_atom(key), do: key
  defp json_safe_key(key) when is_binary(key), do: key

  defp json_safe_key(key) do
    if String.Chars.impl_for(key) do
      to_string(key)
    else
      inspect(key)
    end
  end
end
