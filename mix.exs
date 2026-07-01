defmodule AshEventLog.MixProject do
  use Mix.Project

  @version "0.1.4"

  def project do
    [
      app: :ash_event_log,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      aliases: aliases(),
      description: "An Ash extension for automatic event logging and audit trails on resources.",
      package: package(),
      source_url: "https://github.com/sephianl/ash_event_log"
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/sephianl/ash_event_log"}
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
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      test: ["ash.setup --quiet", "test"]
    ]
  end
end
