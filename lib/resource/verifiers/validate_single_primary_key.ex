defmodule AshEventLog.Resource.Verifiers.ValidateSinglePrimaryKey do
  @moduledoc false
  use Spark.Dsl.Verifier

  def verify(dsl_state) do
    case Ash.Resource.Info.primary_key(dsl_state) do
      [_single] ->
        :ok

      keys ->
        module =
          case dsl_state do
            module when is_atom(module) -> module
            _ -> Spark.Dsl.Verifier.get_persisted(dsl_state, :module)
          end

        {:error,
         Spark.Error.DslError.exception(
           module: module,
           path: [:attributes],
           message:
             "AshEventLog.Resource requires a single-column primary key, " <>
               "but found #{length(keys)} primary key fields: #{inspect(keys)}"
         )}
    end
  end
end
