defmodule AshEventLog.Test.Post do
  use Ash.Resource,
    domain: AshEventLog.Test.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEventLog.Resource]

  postgres do
    table("posts")
    repo(AshEventLog.Test.Repo)
  end

  event_log do
    event_log(AshEventLog.Test.Event)
  end

  actions do
    defaults([:read, :destroy, create: [:title, :body, :secret], update: [:title, :body]])

    create :create_with_note do
      accept([:title, :body])
      argument(:note, :string, allow_nil?: true)
      argument(:internal_ref, :string, sensitive?: true, allow_nil?: true)
    end

    create :create_with_owner do
      accept([:title])
      argument(:owner, :struct, allow_nil?: true)

      argument(:typed_owner, :struct,
        constraints: [instance_of: AshEventLog.Test.Owner],
        allow_nil?: true
      )

      argument(:owners, {:array, :struct},
        constraints: [items: [instance_of: AshEventLog.Test.Owner]],
        allow_nil?: true
      )

      argument(:context, :map, allow_nil?: true)
    end

    update :atomic_update do
      accept([:title])
      require_atomic?(true)
    end

    destroy :atomic_destroy do
      require_atomic?(true)
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:title, :string, allow_nil?: false, public?: true)
    attribute(:body, :string, public?: true)
    attribute(:secret, :string, sensitive?: true, public?: true)
  end
end
