defmodule AshEventLogTest do
  use ExUnit.Case, async: false

  require Logger

  alias AshEventLog.Test.{CompositePkStub, Domain, Event, Post, Repo, TrackedWithIgnore, User}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    :ok
  end

  describe "create (non-atomic)" do
    test "creates an event when a resource is created" do
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{title: "Hello", body: "World"}, domain: Domain)
        |> Ash.create!()

      [event] = Ash.read!(Event, domain: Domain)
      assert event.resource == "AshEventLog.Test.Post"
      refute String.starts_with?(event.resource, "Elixir.")
      assert event.action == "create"
      assert event.action_type == "create"
      assert event.record_id == to_string(post.id)
      assert event.occurred_at != nil
    end

    test "captures cast attributes in event data" do
      Post
      |> Ash.Changeset.for_create(:create, %{title: "Hello", body: "World"}, domain: Domain)
      |> Ash.create!()

      [event] = Ash.read!(Event, domain: Domain)
      assert event.data["title"] == "Hello"
      assert event.data["body"] == "World"
    end

    test "filters sensitive fields from event data" do
      Post
      |> Ash.Changeset.for_create(:create, %{title: "Hello", secret: "s3cret"}, domain: Domain)
      |> Ash.create!()

      [event] = Ash.read!(Event, domain: Domain)
      assert event.data["title"] == "Hello"
      refute Map.has_key?(event.data, "secret")
    end

    test "omits attributes not set on the changeset" do
      Post
      |> Ash.Changeset.for_create(:create, %{title: "Hello"}, domain: Domain)
      |> Ash.create!()

      [event] = Ash.read!(Event, domain: Domain)
      assert event.data["title"] == "Hello"
      refute Map.has_key?(event.data, "body")
    end
  end

  describe "update (non-atomic)" do
    test "creates an event when a resource is updated" do
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{title: "Hello"}, domain: Domain)
        |> Ash.create!()

      post
      |> Ash.Changeset.for_update(:update, %{title: "Updated"}, domain: Domain)
      |> Ash.update!()

      events = Ash.read!(Event, domain: Domain)
      assert length(events) == 2

      update_event = Enum.find(events, &(&1.action == "update"))
      assert update_event.record_id == to_string(post.id)
      assert update_event.data["title"] == "Updated"
    end
  end

  describe "destroy (non-atomic)" do
    test "creates an event when a resource is destroyed" do
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{title: "Hello"}, domain: Domain)
        |> Ash.create!()

      post
      |> Ash.Changeset.for_destroy(:destroy, %{}, domain: Domain)
      |> Ash.destroy!()

      events = Ash.read!(Event, domain: Domain)
      assert length(events) == 2

      destroy_event = Enum.find(events, &(&1.action == "destroy"))
      assert destroy_event.record_id == to_string(post.id)
      assert destroy_event.action_type == "destroy"
    end
  end

  describe "atomic update" do
    test "creates event for atomic update" do
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{title: "Hello"}, domain: Domain)
        |> Ash.create!()

      Ash.bulk_update!([post], :update, %{title: "Atomic Updated"},
        domain: Domain,
        strategy: :atomic,
        return_errors?: true,
        authorize?: false
      )

      events = Ash.read!(Event, domain: Domain)
      update_event = Enum.find(events, &(&1.action == "update"))
      assert update_event != nil
      assert update_event.record_id == to_string(post.id)
      assert update_event.action_type == "update"
      assert update_event.data["title"] == "Atomic Updated"
    end

    test "records only the changed attributes" do
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{title: "Hello", body: "World"}, domain: Domain)
        |> Ash.create!()

      Ash.bulk_update!([post], :update, %{title: "Changed"},
        domain: Domain,
        strategy: :atomic,
        return_errors?: true,
        authorize?: false
      )

      events = Ash.read!(Event, domain: Domain)
      update_event = Enum.find(events, &(&1.action == "update"))
      assert update_event.data["title"] == "Changed"
      refute Map.has_key?(update_event.data, "body")
    end

    test "persists actor on atomic update" do
      user =
        User
        |> Ash.Changeset.for_create(:create, %{name: "Test User"}, domain: Domain)
        |> Ash.create!()

      post =
        Post
        |> Ash.Changeset.for_create(:create, %{title: "Hello"}, domain: Domain)
        |> Ash.create!()

      Ash.bulk_update!([post], :update, %{title: "Atomic"},
        domain: Domain,
        strategy: :atomic,
        return_errors?: true,
        authorize?: false,
        actor: user
      )

      events = Ash.read!(Event, domain: Domain)
      update_event = Enum.find(events, &(&1.action == "update"))
      assert update_event.user_id == user.id
    end
  end

  describe "atomic destroy" do
    test "creates event for atomic destroy" do
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{title: "Hello"}, domain: Domain)
        |> Ash.create!()

      Ash.bulk_destroy!([post], :destroy, %{},
        domain: Domain,
        strategy: :atomic,
        return_errors?: true,
        authorize?: false
      )

      events = Ash.read!(Event, domain: Domain)
      destroy_event = Enum.find(events, &(&1.action == "destroy"))
      assert destroy_event != nil
      assert destroy_event.record_id == to_string(post.id)
      assert destroy_event.action_type == "destroy"
    end
  end

  describe "bulk create (batch)" do
    test "creates events for bulk_create" do
      inputs = [%{title: "First"}, %{title: "Second"}, %{title: "Third"}]

      Ash.bulk_create!(inputs, Post, :create, domain: Domain)

      events = Ash.read!(Event, domain: Domain)
      create_events = Enum.filter(events, &(&1.action == "create"))
      assert length(create_events) == 3
    end

    test "records correct data for each bulk-created record" do
      Ash.bulk_create!([%{title: "Alpha"}, %{title: "Beta"}], Post, :create, domain: Domain)

      events = Ash.read!(Event, domain: Domain)
      titles = events |> Enum.map(& &1.data["title"]) |> Enum.sort()
      assert titles == ["Alpha", "Beta"]
    end

    test "persists actor on bulk-created events" do
      user =
        User
        |> Ash.Changeset.for_create(:create, %{name: "Bulk Actor"}, domain: Domain)
        |> Ash.create!()

      Ash.bulk_create!([%{title: "A"}, %{title: "B"}], Post, :create,
        domain: Domain,
        actor: user
      )

      events = Ash.read!(Event, domain: Domain)
      assert Enum.all?(events, &(&1.user_id == user.id))
    end
  end

  describe "ignore_actions" do
    test "does not create events for ignored actions (non-atomic)" do
      item =
        TrackedWithIgnore
        |> Ash.Changeset.for_create(:create, %{name: "Item"}, domain: Domain)
        |> Ash.create!()

      item
      |> Ash.Changeset.for_update(:background_update, %{name: "Updated"}, domain: Domain)
      |> Ash.update!()

      events = Ash.read!(Event, domain: Domain)
      assert length(events) == 1
      assert hd(events).action == "create"
    end

    test "does not create events for ignored actions (single-record atomic)" do
      item =
        TrackedWithIgnore
        |> Ash.Changeset.for_create(:create, %{name: "Item"}, domain: Domain)
        |> Ash.create!()

      item
      |> Ash.Changeset.for_update(:background_update, %{name: "Silently Updated"},
        domain: Domain,
        authorize?: false
      )
      |> Ash.update!()

      events = Ash.read!(Event, domain: Domain)
      assert length(events) == 1
      assert hd(events).action == "create"
    end

    test "does not create events for ignored bulk actions (atomic)" do
      inputs = [%{name: "A"}, %{name: "B"}]
      Ash.bulk_create!(inputs, TrackedWithIgnore, :create, domain: Domain)

      items = Ash.read!(TrackedWithIgnore, domain: Domain)

      Ash.bulk_update!(items, :background_update, %{name: "Updated"},
        domain: Domain,
        strategy: :atomic,
        return_errors?: true,
        authorize?: false
      )

      events = Ash.read!(Event, domain: Domain)
      assert Enum.all?(events, &(&1.action == "create"))
    end
  end

  describe "action arguments" do
    test "captures non-sensitive arguments in event data" do
      Post
      |> Ash.Changeset.for_create(:create_with_note, %{title: "Hello", note: "a note"},
        domain: Domain
      )
      |> Ash.create!()

      [event] = Ash.read!(Event, domain: Domain)
      assert event.data["title"] == "Hello"
      assert event.data["note"] == "a note"
    end

    test "filters sensitive arguments from event data" do
      Post
      |> Ash.Changeset.for_create(
        :create_with_note,
        %{title: "Hello", note: "visible", internal_ref: "secret-ref"},
        domain: Domain
      )
      |> Ash.create!()

      [event] = Ash.read!(Event, domain: Domain)
      assert event.data["note"] == "visible"
      refute Map.has_key?(event.data, "internal_ref")
    end
  end

  describe "metadata" do
    test "stores metadata from changeset context" do
      Post
      |> Ash.Changeset.for_create(:create, %{title: "Hello"}, domain: Domain)
      |> Ash.Changeset.set_context(%{
        ash_event_log_metadata: %{source: "test", request_id: "abc"}
      })
      |> Ash.create!()

      [event] = Ash.read!(Event, domain: Domain)
      assert event.metadata["source"] == "test"
      assert event.metadata["request_id"] == "abc"
    end

    test "captures Logger metadata automatically" do
      Logger.metadata(request_id: "req-123")

      Post
      |> Ash.Changeset.for_create(:create, %{title: "Hello"}, domain: Domain)
      |> Ash.create!()

      [event] = Ash.read!(Event, domain: Domain)
      assert event.metadata["request_id"] == "req-123"
    after
      Logger.metadata(request_id: nil)
    end

    test "wildcard captures all Logger metadata" do
      Logger.metadata(request_id: "req-123", trace_id: "trace-456")

      Post
      |> Ash.Changeset.for_create(:create, %{title: "Hello"}, domain: Domain)
      |> Ash.create!()

      [event] = Ash.read!(Event, domain: Domain)
      assert event.metadata["request_id"] == "req-123"
      assert event.metadata["trace_id"] == "trace-456"
    after
      Logger.metadata(request_id: nil, trace_id: nil)
    end

    test "wildcard excludes persist_actor_primary_key names from metadata" do
      Logger.metadata(user_id: "should-be-excluded", request_id: "req-789")

      Post
      |> Ash.Changeset.for_create(:create, %{title: "Hello"}, domain: Domain)
      |> Ash.create!()

      [event] = Ash.read!(Event, domain: Domain)
      assert event.metadata["request_id"] == "req-789"
      refute Map.has_key?(event.metadata, "user_id")
    after
      Logger.metadata(user_id: nil, request_id: nil)
    end

    test "explicit context overrides Logger metadata" do
      Logger.metadata(request_id: "from-logger")

      Post
      |> Ash.Changeset.for_create(:create, %{title: "Hello"}, domain: Domain)
      |> Ash.Changeset.set_context(%{
        ash_event_log_metadata: %{request_id: "from-context"}
      })
      |> Ash.create!()

      [event] = Ash.read!(Event, domain: Domain)
      assert event.metadata["request_id"] == "from-context"
    after
      Logger.metadata(request_id: nil)
    end
  end

  describe "actor persistence" do
    test "stores actor user_id on event" do
      user =
        User
        |> Ash.Changeset.for_create(:create, %{name: "Test User"}, domain: Domain)
        |> Ash.create!()

      Post
      |> Ash.Changeset.for_create(:create, %{title: "Hello"},
        domain: Domain,
        actor: user
      )
      |> Ash.create!()

      [event] = Ash.read!(Event, domain: Domain)
      assert event.user_id == user.id
    end

    test "leaves user_id nil when no actor" do
      Post
      |> Ash.Changeset.for_create(:create, %{title: "Hello"}, domain: Domain)
      |> Ash.create!()

      [event] = Ash.read!(Event, domain: Domain)
      assert event.user_id == nil
    end

    test "does not crash with non-Ash struct actor" do
      actor = %{__struct__: SomeNonAshModule, id: "123"}

      Post
      |> Ash.Changeset.for_create(:create, %{title: "Hello"},
        domain: Domain,
        actor: actor
      )
      |> Ash.create!()

      [event] = Ash.read!(Event, domain: Domain)
      assert event.user_id == nil
    end

    test "does not crash with non-struct actor" do
      Post
      |> Ash.Changeset.for_create(:create, %{title: "Hello"},
        domain: Domain,
        actor: %{id: "123"}
      )
      |> Ash.create!()

      [event] = Ash.read!(Event, domain: Domain)
      assert event.user_id == nil
    end
  end

  describe "json safety" do
    test "converts raw binary UUIDs in Logger metadata to strings" do
      raw_uuid = <<1, 0, 5, 88, 192, 188, 64, 211, 161, 193, 16, 248, 166, 136, 238, 245>>
      Logger.metadata(trace_id: raw_uuid)

      Post
      |> Ash.Changeset.for_create(:create, %{title: "Hello"}, domain: Domain)
      |> Ash.create!()

      [event] = Ash.read!(Event, domain: Domain)
      assert event.metadata["trace_id"] == "01000558-c0bc-40d3-a1c1-10f8a688eef5"
    after
      Logger.metadata(trace_id: nil)
    end

    test "converts raw binary UUIDs in explicit metadata to strings" do
      raw_uuid = <<1, 0, 5, 88, 192, 188, 64, 211, 161, 193, 16, 248, 166, 136, 238, 245>>

      Post
      |> Ash.Changeset.for_create(:create, %{title: "Hello"}, domain: Domain)
      |> Ash.Changeset.set_context(%{
        ash_event_log_metadata: %{parent_id: raw_uuid}
      })
      |> Ash.create!()

      [event] = Ash.read!(Event, domain: Domain)
      assert event.metadata["parent_id"] == "01000558-c0bc-40d3-a1c1-10f8a688eef5"
    end

    test "converts tuples in Logger metadata to lists" do
      Logger.metadata(dimensions: {100, 200})

      Post
      |> Ash.Changeset.for_create(:create, %{title: "Hello"}, domain: Domain)
      |> Ash.create!()

      [event] = Ash.read!(Event, domain: Domain)
      assert event.metadata["dimensions"] == [100, 200]
    after
      Logger.metadata(dimensions: nil)
    end

    test "converts pids in Logger metadata to strings" do
      Logger.metadata(caller_pid: self())

      Post
      |> Ash.Changeset.for_create(:create, %{title: "Hello"}, domain: Domain)
      |> Ash.create!()

      [event] = Ash.read!(Event, domain: Domain)
      assert is_binary(event.metadata["caller_pid"])
      assert String.starts_with?(event.metadata["caller_pid"], "#PID<")
    after
      Logger.metadata(caller_pid: nil)
    end

    test "handles nested maps with binary UUIDs" do
      raw_uuid = <<1, 0, 5, 88, 192, 188, 64, 211, 161, 193, 16, 248, 166, 136, 238, 245>>

      Post
      |> Ash.Changeset.for_create(:create, %{title: "Hello"}, domain: Domain)
      |> Ash.Changeset.set_context(%{
        ash_event_log_metadata: %{nested: %{id: raw_uuid, name: "test"}}
      })
      |> Ash.create!()

      [event] = Ash.read!(Event, domain: Domain)
      assert event.metadata["nested"]["id"] == "01000558-c0bc-40d3-a1c1-10f8a688eef5"
      assert event.metadata["nested"]["name"] == "test"
    end
  end

  describe "composite primary key verifier" do
    test "rejects resources with composite primary keys" do
      assert {:error, error} =
               AshEventLog.Resource.Verifiers.ValidateSinglePrimaryKey.verify(CompositePkStub)

      assert Exception.message(error) =~ "single-column primary key"
    end

    test "accepts resources with single primary key" do
      assert :ok = AshEventLog.Resource.Verifiers.ValidateSinglePrimaryKey.verify(Post)
    end
  end
end
