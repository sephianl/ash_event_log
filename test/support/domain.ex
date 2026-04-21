defmodule AshEventLog.Test.Domain do
  use Ash.Domain

  resources do
    resource AshEventLog.Test.Event
    resource AshEventLog.Test.Post
    resource AshEventLog.Test.TrackedWithIgnore
  end
end
