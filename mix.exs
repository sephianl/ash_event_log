defmodule AshEventLog.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :ash_event_log,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      aliases: aliases()
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
      {:jason, "~> 1.0"}
    ]
  end

  defp aliases do
    [
      test: ["ash.setup --quiet", "test"]
    ]
  end
end
