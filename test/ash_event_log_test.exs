defmodule AshEventLogTest do
  use ExUnit.Case, async: false

  alias AshEventLog.Test.{Domain, Event, Post, Repo, TrackedWithIgnore}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    :ok
  end

  describe "create" do
    test "creates an event when a resource is created" do
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{title: "Hello", body: "World"}, domain: Domain)
        |> Ash.create!()

      events = Ash.read!(Event, domain: Domain)
      assert length(events) == 1

      event = hd(events)
      assert event.resource == to_string(Post)
      assert event.action == "create"
      assert event.action_type == "create"
      assert event.record_id == to_string(post.id)
      assert event.data["title"] == "Hello"
      assert event.data["body"] == "World"
      assert event.occurred_at != nil
    end

    test "filters sensitive fields from event data" do
      Post
      |> Ash.Changeset.for_create(:create, %{title: "Hello", secret: "s3cret"}, domain: Domain)
      |> Ash.create!()

      event = Ash.read!(Event, domain: Domain) |> hd()
      assert event.data["title"] == "Hello"
      refute Map.has_key?(event.data, :secret)
      refute Map.has_key?(event.data, "secret")
    end
  end

  describe "update" do
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

  describe "destroy" do
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

  describe "ignore_actions" do
    test "does not create events for ignored actions" do
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
  end

  describe "metadata" do
    test "stores metadata from changeset context" do
      Post
      |> Ash.Changeset.for_create(:create, %{title: "Hello"}, domain: Domain)
      |> Ash.Changeset.set_context(%{ash_event_log_metadata: %{source: "test", request_id: "abc"}})
      |> Ash.create!()

      event = Ash.read!(Event, domain: Domain) |> hd()
      assert event.metadata["source"] == "test"
      assert event.metadata["request_id"] == "abc"
    end
  end
end
