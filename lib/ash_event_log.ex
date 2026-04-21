defmodule AshEventLog do
  @moduledoc """
  Lightweight centralized event logging for Ash resources.

  Two extensions:

  - `AshEventLog.EventLog` — applied to the event resource, generates schema
  - `AshEventLog.Resource` — applied to tracked resources, injects event creation
  """
end
