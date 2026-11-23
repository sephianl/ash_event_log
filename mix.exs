defmodule AshEventLog.MixProject do
  use Mix.Project

  @version "0.1.6"
  @github_url "https://github.com/sephianl/ash_event_log"

  def project do
    [
      app: :ash_event_log,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      aliases: aliases(),

      # Hex
      description: "An Ash extension for automatic event logging and audit trails on resources.",
      package: package(),

      # Docs
      name: "AshEventLog",
      docs: &docs/0,
      source_url: @github_url
    ]
  end

  defp package do
    [
      maintainers: ["Sephia"],
      licenses: ["MIT"],
      files: ~w(lib .formatter.exs mix.exs README* LICENSE* CHANGELOG*
                documentation usage-rules.md),
      links: %{
        "GitHub" => @github_url,
        "Changelog" => "#{@github_url}/blob/main/CHANGELOG.md"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @github_url,
      source_ref: "v#{@version}",
      extras: [
        {"README.md", title: "Home"},
        {"documentation/dsls/DSL-AshEventLog.EventLog.md",
         search_data: Spark.Docs.search_data_for(AshEventLog.EventLog)},
        {"documentation/dsls/DSL-AshEventLog.Resource.md",
         search_data: Spark.Docs.search_data_for(AshEventLog.Resource)},
        "usage-rules.md",
        "CHANGELOG.md"
      ],
      groups_for_extras: [
        Reference: ~r"documentation/dsls",
        "About AshEventLog": ["usage-rules.md", "CHANGELOG.md"]
      ],
      groups_for_modules: [
        Extensions: [
          AshEventLog.EventLog,
          AshEventLog.Resource
        ],
        Introspection: [
          AshEventLog.EventLog.PersistActorPrimaryKey
        ]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:ash, "~> 3.0"},
      {:ash_postgres, "~> 2.0"},
      {:spark, "~> 2.0"},
      {:postgrex, "~> 0.21"},
      {:jason, "~> 1.0"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      # Required by `mix spark.formatter` and `mix spark.cheat_sheets`
      {:sourceror, "~> 1.2", only: [:dev, :test], runtime: false},
      {:igniter, "~> 0.6", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      test: ["ash.setup --quiet", "test"],
      docs: ["spark.cheat_sheets", "docs", "spark.replace_doc_links"],
      "spark.formatter": "spark.formatter --extensions AshEventLog.Resource,AshEventLog.EventLog",
      "spark.cheat_sheets":
        "spark.cheat_sheets --extensions AshEventLog.Resource,AshEventLog.EventLog"
    ]
  end
end
