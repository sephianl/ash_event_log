defmodule AshEventLog.FireAndForgetTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias AshEventLog.Test.{Domain, Post, Repo}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    :ok
  end

  test "business action succeeds even when async event creation fails" do
    Application.put_env(:ash, :disable_async?, false)

    log =
      capture_log(fn ->
        post =
          Post
          |> Ash.Changeset.for_create(:create, %{title: "Hello"}, domain: Domain)
          |> Ash.create!()

        assert post.title == "Hello"
        # Wait for the async Task to hit the ownership error and log it
        Process.sleep(100)
      end)

    assert log =~ "AshEventLog: failed to create event"
  after
    Application.put_env(:ash, :disable_async?, true)
  end
end
