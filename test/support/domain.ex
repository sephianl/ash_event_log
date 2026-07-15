defmodule AshEventLog.Test.Domain do
  use Ash.Domain

  resources do
    resource(AshEventLog.Test.Event)
    resource(AshEventLog.Test.Post)
    resource(AshEventLog.Test.TrackedWithIgnore)
    resource(AshEventLog.Test.TrackedWithOnly)
    resource(AshEventLog.Test.User)
    resource(AshEventLog.Test.TenantEvent)
    resource(AshEventLog.Test.TenantPost)
  end
end
