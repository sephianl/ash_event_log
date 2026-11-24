defmodule AshEventLog.Test.Domain do
  use Ash.Domain

  resources do
    resource(AshEventLog.Test.Event)
    resource(AshEventLog.Test.Owner)
    resource(AshEventLog.Test.Post)
    resource(AshEventLog.Test.TrackedWithIgnore)
    resource(AshEventLog.Test.TrackedWithOnly)
    resource(AshEventLog.Test.User)
  end
end
