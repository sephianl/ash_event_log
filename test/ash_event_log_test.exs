defmodule AshEventLogTest do
  use ExUnit.Case, async: false

  require Logger

  alias AshEventLog.Test.{
    CompositePkStub,
    Domain,
    Event,
    Owner,
    Post,
    Repo,
    TrackedWithIgnore,
    TrackedWithOnly,
    User
  }

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

    test "logs exactly one event per record for a bulk atomic update" do
      posts =
        Enum.map(1..3, fn i ->
          Post
          |> Ash.Changeset.for_create(:create, %{title: "Post #{i}"}, domain: Domain)
          |> Ash.create!()
        end)

      Ash.bulk_update!(posts, :update, %{title: "Bulk Atomic"},
        domain: Domain,
        strategy: :atomic,
        return_errors?: true,
        authorize?: false
      )

      events = Ash.read!(Event, domain: Domain)
      assert Enum.count(events, &(&1.action == "update")) == 3
    end

    test "logs exactly one event for a single-record atomic update" do
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{title: "Hello"}, domain: Domain)
        |> Ash.create!()

      post
      |> Ash.Changeset.for_update(:atomic_update, %{title: "Single Atomic"}, domain: Domain)
      |> Ash.update!()

      events = Ash.read!(Event, domain: Domain)
      assert Enum.count(events, &(&1.action == "atomic_update")) == 1

      update_event = Enum.find(events, &(&1.action == "atomic_update"))
      assert update_event.record_id == to_string(post.id)
      assert update_event.action_type == "update"
      assert update_event.data["title"] == "Single Atomic"
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

    test "logs exactly one event per record for a bulk atomic destroy" do
      posts =
        Enum.map(1..3, fn i ->
          Post
          |> Ash.Changeset.for_create(:create, %{title: "Post #{i}"}, domain: Domain)
          |> Ash.create!()
        end)

      Ash.bulk_destroy!(posts, :destroy, %{},
        domain: Domain,
        strategy: :atomic,
        return_errors?: true,
        authorize?: false
      )

      events = Ash.read!(Event, domain: Domain)
      assert Enum.count(events, &(&1.action == "destroy")) == 3
    end

    test "logs exactly one event for a single-record atomic destroy" do
      # Single-record atomic destroys never touch the batch machinery — they
      # log via `change/3`'s `after_action`, not `after_batch`. This guards
      # that path, which no bulk test exercises.
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{title: "Hello"}, domain: Domain)
        |> Ash.create!()

      post
      |> Ash.Changeset.for_destroy(:atomic_destroy, %{}, domain: Domain)
      |> Ash.destroy!()

      events = Ash.read!(Event, domain: Domain)
      assert Enum.count(events, &(&1.action == "atomic_destroy")) == 1

      destroy_event = Enum.find(events, &(&1.action == "atomic_destroy"))
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

  describe "only_actions" do
    test "creates events only for listed actions (non-atomic)" do
      item =
        TrackedWithOnly
        |> Ash.Changeset.for_create(:create, %{name: "Item"}, domain: Domain)
        |> Ash.create!()

      item
      |> Ash.Changeset.for_update(:update, %{name: "Updated"}, domain: Domain)
      |> Ash.update!()

      item
      |> Ash.Changeset.for_update(:background_update, %{name: "Background"}, domain: Domain)
      |> Ash.update!()

      events = Ash.read!(Event, domain: Domain)
      actions = events |> Enum.map(& &1.action) |> Enum.sort()
      assert actions == ["create"]
    end

    test "creates events only for listed actions (single-record atomic)" do
      item =
        TrackedWithOnly
        |> Ash.Changeset.for_create(:create, %{name: "Item"}, domain: Domain)
        |> Ash.create!()

      item
      |> Ash.Changeset.for_update(:update, %{name: "Updated"},
        domain: Domain,
        authorize?: false
      )
      |> Ash.update!()

      events = Ash.read!(Event, domain: Domain)
      assert length(events) == 1
      assert hd(events).action == "create"
    end

    test "creates events only for listed actions in bulk (atomic)" do
      inputs = [%{name: "A"}, %{name: "B"}]
      Ash.bulk_create!(inputs, TrackedWithOnly, :create, domain: Domain)

      items = Ash.read!(TrackedWithOnly, domain: Domain)

      Ash.bulk_update!(items, :update, %{name: "Updated"},
        domain: Domain,
        strategy: :atomic,
        return_errors?: true,
        authorize?: false
      )

      events = Ash.read!(Event, domain: Domain)
      assert Enum.all?(events, &(&1.action == "create"))
      assert length(events) == 2
    end

    test "logs destroy events when listed" do
      item =
        TrackedWithOnly
        |> Ash.Changeset.for_create(:create, %{name: "Item"}, domain: Domain)
        |> Ash.create!()

      item
      |> Ash.Changeset.for_destroy(:destroy, %{}, domain: Domain)
      |> Ash.destroy!()

      events = Ash.read!(Event, domain: Domain)
      actions = events |> Enum.map(& &1.action) |> Enum.sort()
      assert actions == ["create", "destroy"]
    end

    test "rejects resources that set both ignore_actions and only_actions" do
      assert_raise Spark.Error.DslError, ~r/mutually exclusive/, fn ->
        defmodule InvalidConflict do
          use Ash.Resource,
            domain: AshEventLog.Test.Domain,
            data_layer: AshPostgres.DataLayer,
            extensions: [AshEventLog.Resource]

          postgres do
            table("invalid_conflict")
            repo(AshEventLog.Test.Repo)
          end

          event_log do
            event_log(AshEventLog.Test.Event)
            ignore_actions([:update])
            only_actions([:create])
          end

          actions do
            defaults([:read, :destroy, create: [:name], update: [:name]])
          end

          attributes do
            uuid_primary_key(:id)
            attribute(:name, :string, allow_nil?: false, public?: true)
          end
        end
      end
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

  describe "dates and times" do
    test "are stored as ISO 8601 strings" do
      Post
      |> Ash.Changeset.for_create(
        :create_with_schedule,
        %{
          title: "Hello",
          publish_at: ~U[2026-11-23 10:15:30.123456Z],
          drafted_at: ~N[2026-11-22 09:00:00],
          publish_on: ~D[2026-11-23],
          publish_time: ~T[10:15:30]
        },
        domain: Domain
      )
      |> Ash.create!()

      [event] = Ash.read!(Event, domain: Domain)
      assert event.data["publish_at"] == "2026-11-23T10:15:30.123456Z"
      assert event.data["drafted_at"] == "2026-11-22T09:00:00"
      assert event.data["publish_on"] == "2026-11-23"
      assert event.data["publish_time"] == "10:15:30"
    end

    test "are stored as ISO 8601 strings when nested in a map" do
      Post
      |> Ash.Changeset.for_create(
        :create_with_schedule,
        %{title: "Hello", context: %{"window" => [~U[2026-11-23 10:00:00Z], ~D[2026-11-24]]}},
        domain: Domain
      )
      |> Ash.create!()

      [event] = Ash.read!(Event, domain: Domain)
      assert event.data["context"]["window"] == ["2026-11-23T10:00:00Z", "2026-11-24"]
    end

    test "are stored as ISO 8601 strings in metadata" do
      Post
      |> Ash.Changeset.for_create(:create, %{title: "Hello"}, domain: Domain)
      |> Ash.Changeset.set_context(%{ash_event_log_metadata: %{at: ~U[2026-11-23 10:00:00Z]}})
      |> Ash.create!()

      [event] = Ash.read!(Event, domain: Domain)
      assert event.metadata["at"] == "2026-11-23T10:00:00Z"
    end
  end

  describe "record arguments" do
    setup do
      mentor = %Owner{id: Ash.UUID.generate(), name: "Mentor", hashed_password: "$2b$mentor"}

      owner = %Owner{
        id: Ash.UUID.generate(),
        name: "Owner",
        hashed_password: "$2b$owner",
        joined_at: ~U[2026-11-23 10:00:00.000000Z],
        mentor_id: mentor.id,
        mentor: mentor
      }

      %{owner: owner}
    end

    test "keep only the record's non-sensitive attributes", %{owner: owner} do
      create_with_owner!(%{owner: owner})

      [event] = Ash.read!(Event, domain: Domain)

      assert event.data["owner"] == %{
               "id" => owner.id,
               "name" => "Owner",
               "joined_at" => "2026-11-23T10:00:00.000000Z",
               "mentor_id" => owner.mentor_id
             }
    end

    test "drop sensitive attributes when the argument names the resource", %{owner: owner} do
      create_with_owner!(%{typed_owner: owner})

      [event] = Ash.read!(Event, domain: Domain)
      assert event.data["typed_owner"]["name"] == "Owner"
      refute Map.has_key?(event.data["typed_owner"], "hashed_password")
    end

    test "drop sensitive attributes from every record in a list", %{owner: owner} do
      create_with_owner!(%{owners: [owner, owner.mentor]})

      [event] = Ash.read!(Event, domain: Domain)
      assert Enum.map(event.data["owners"], & &1["name"]) == ["Owner", "Mentor"]
      refute Enum.any?(event.data["owners"], &Map.has_key?(&1, "hashed_password"))
    end

    test "drop sensitive attributes from records nested in a map", %{owner: owner} do
      create_with_owner!(%{context: %{"by" => owner}})

      [event] = Ash.read!(Event, domain: Domain)
      assert event.data["context"]["by"]["name"] == "Owner"
      refute Map.has_key?(event.data["context"]["by"], "hashed_password")
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

  describe "json_safe_key" do
    test "handles tuple keys in data maps without crashing" do
      Post
      |> Ash.Changeset.for_create(:create, %{title: "Hello"}, domain: Domain)
      |> Ash.Changeset.set_context(%{
        ash_event_log_metadata: %{{:tuple_key, :example} => "value"}
      })
      |> Ash.create!()

      [event] = Ash.read!(Event, domain: Domain)
      assert event.metadata["{:tuple_key, :example}"] == "value"
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

  defp create_with_owner!(arguments) do
    Post
    |> Ash.Changeset.for_create(:create_with_owner, Map.put(arguments, :title, "Hello"),
      domain: Domain
    )
    |> Ash.create!()
  end
end
