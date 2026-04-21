defmodule AshEventLog.Resource.Changes.CreateEvent do
  @moduledoc false
  use Ash.Resource.Change

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def change(changeset, opts, context) do
    if changeset.action.name in opts[:ignore_actions] do
      changeset
    else
      event_log = opts[:event_log]

      Ash.Changeset.after_action(changeset, fn changeset, result ->
        params = build_event_params(changeset, result, event_log, context)

        case create_event(event_log, params) do
          {:ok, _event} -> {:ok, result}
          {:error, error} -> {:error, error}
        end
      end)
    end
  end

  @impl true
  def atomic(_changeset, _opts, _context), do: :ok

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

    if events != [] do
      Ash.bulk_create(events, event_log, :create,
        authorize?: false,
        return_errors?: true,
        stop_on_error?: true
      )
    end

    Enum.map(changesets_and_results, fn {_, result} -> {:ok, result} end)
  end

  defp create_event(event_log, params) do
    event_log
    |> Ash.Changeset.for_create(:create, params, authorize?: false)
    |> Ash.create(authorize?: false)
  end

  defp build_event_params(changeset, result, event_log, context) do
    actor_params = build_actor_params(event_log, Map.get(context, :actor))

    %{
      record_id: get_record_id(changeset, result),
      resource: to_string(changeset.resource),
      action: to_string(changeset.action.name),
      action_type: to_string(changeset.action_type),
      data: extract_params(changeset),
      metadata: Map.get(changeset.context, :ash_event_log_metadata, %{}),
      occurred_at: DateTime.utc_now()
    }
    |> Map.merge(actor_params)
  end

  defp build_actor_params(_event_log, actor) when not is_struct(actor), do: %{}

  defp build_actor_params(event_log, actor) do
    event_log
    |> AshEventLog.EventLog.Info.persist_actor_primary_keys()
    |> Enum.reduce(%{}, fn config, acc ->
      if actor.__struct__ == config.destination do
        pk_field = hd(Ash.Resource.Info.primary_key(actor.__struct__))
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
        :create -> Map.get(result, pk)
        _ -> Map.get(changeset.data, pk)
      end

    if id, do: to_string(id)
  end

  defp extract_params(changeset) do
    Enum.reduce(changeset.params, %{}, fn {key, value}, acc ->
      key_atom = to_existing_atom(key)

      if key_atom do
        attr = Ash.Resource.Info.attribute(changeset.resource, key_atom)
        arg = Enum.find(changeset.action.arguments, &(&1.name == key_atom))

        cond do
          (attr && attr.sensitive?) or (arg && arg.sensitive?) -> acc
          attr || arg -> Map.put(acc, key_atom, dump_value(value, attr || arg))
          true -> acc
        end
      else
        acc
      end
    end)
  end

  defp dump_value(value, %{type: type, constraints: constraints}) do
    case Ash.Type.dump_to_embedded(type, value, constraints || []) do
      {:ok, dumped} -> dumped
      _ -> value
    end
  rescue
    _ -> value
  end

  defp to_existing_atom(key) when is_atom(key), do: key

  defp to_existing_atom(key) when is_binary(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> nil
  end
end
