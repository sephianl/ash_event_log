defmodule AshEventLog.MultitenancyTest do
  @moduledoc """
  Regression tests for the bug where `CreateEvent` created the event record
  without forwarding the tenant of the tracked action, causing
  `Ash.Error.Invalid.TenantRequired` (swallowed and merely logged) whenever
  the event log resource itself is multitenant.
  """
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias AshEventLog.Test.{Domain, Repo, TenantEvent, TenantPost}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    :ok
  end

  describe "non-atomic create" do
    test "logs the event under the same tenant as the tracked action" do
      log =
        capture_log(fn ->
          post =
            TenantPost
            |> Ash.Changeset.for_create(:create, %{title: "Hello"},
              domain: Domain,
              tenant: "tenant-a"
            )
            |> Ash.create!()

          assert post.title == "Hello"
        end)

      refute log =~ "TenantRequired"

      events = Ash.read!(TenantEvent, domain: Domain, tenant: "tenant-a")
      assert Enum.any?(events, &(&1.action == "create"))
    end
  end

  describe "non-atomic update" do
    test "logs the event under the same tenant as the tracked action" do
      post =
        TenantPost
        |> Ash.Changeset.for_create(:create, %{title: "Hello"},
          domain: Domain,
          tenant: "tenant-b"
        )
        |> Ash.create!()

      post
      |> Ash.Changeset.for_update(:update, %{title: "Updated"},
        domain: Domain,
        tenant: "tenant-b"
      )
      |> Ash.update!()

      events = Ash.read!(TenantEvent, domain: Domain, tenant: "tenant-b")
      assert Enum.any?(events, &(&1.action == "update"))
    end
  end

  describe "single-record atomic update" do
    test "logs the event under the same tenant as the tracked action" do
      post =
        TenantPost
        |> Ash.Changeset.for_create(:create, %{title: "Hello"},
          domain: Domain,
          tenant: "tenant-c"
        )
        |> Ash.create!()

      post
      |> Ash.Changeset.for_update(:atomic_update, %{title: "Updated"},
        domain: Domain,
        tenant: "tenant-c"
      )
      |> Ash.update!()

      events = Ash.read!(TenantEvent, domain: Domain, tenant: "tenant-c")
      assert Enum.any?(events, &(&1.action == "atomic_update"))
    end
  end

  describe "bulk create (batch)" do
    test "logs events under the tenant used for the bulk create" do
      Ash.bulk_create!([%{title: "A"}, %{title: "B"}], TenantPost, :create,
        domain: Domain,
        tenant: "tenant-d"
      )

      events = Ash.read!(TenantEvent, domain: Domain, tenant: "tenant-d")
      assert Enum.count(events, &(&1.action == "create")) == 2
    end
  end

  describe "bulk atomic update" do
    test "logs events under the tenant used for the bulk update" do
      posts =
        Enum.map(1..2, fn i ->
          TenantPost
          |> Ash.Changeset.for_create(:create, %{title: "Post #{i}"},
            domain: Domain,
            tenant: "tenant-e"
          )
          |> Ash.create!()
        end)

      Ash.bulk_update!(posts, :update, %{title: "Bulk Atomic"},
        domain: Domain,
        tenant: "tenant-e",
        strategy: :atomic,
        return_errors?: true,
        authorize?: false
      )

      events = Ash.read!(TenantEvent, domain: Domain, tenant: "tenant-e")
      assert Enum.count(events, &(&1.action == "update")) == 2
    end
  end

  describe "cross-tenant isolation" do
    test "events for one tenant are not visible from another tenant" do
      TenantPost
      |> Ash.Changeset.for_create(:create, %{title: "Isolated"},
        domain: Domain,
        tenant: "tenant-f"
      )
      |> Ash.create!()

      events = Ash.read!(TenantEvent, domain: Domain, tenant: "tenant-g")
      refute Enum.any?(events, &(&1.data["title"] == "Isolated"))
    end
  end
end
