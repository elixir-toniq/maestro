defmodule Maestro.Mixfile do
  use Mix.Project

  @version "1.0.1"
  @source_url "https://github.com/elixir-toniq/maestro"

  def project do
    [
      app: :maestro,
      version: @version,
      elixir: "~> 1.16",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      package: package(),
      description: description(),
      deps: deps(),
      name: "Maestro",
      source_url: @source_url,
      docs: [
        source_url: @source_url,
        extras: ["README.md"]
      ],
      dialyzer: [
        plt_add_apps: [:mix, :ex_unit],
        flags: [:error_handling]
      ]
    ]
  end

  def application do
    [
      mod: {Maestro.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:ecto, "~> 3.0"},
      {:ecto_sql, "~> 3.0"},
      {:postgrex, ">= 0.0.0"},
      {:ecto_hlclock, "~> 0.4"},
      {:jason, "~> 1.1"},
      {:mock, "~> 0.3", only: :test, runtime: false},
      {:castore, "~> 1.0", only: [:dev, :test]},
      {:credo, "~> 1.0", only: [:dev, :test]},
      {:stream_data, "~> 1.0", only: [:dev, :test]},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:benchee, "~> 1.0", only: :dev},
      {:ex_doc, "~> 0.16", only: :dev}
    ]
  end

  defp description do
    """
    Maestro: event sourcing
    """
  end

  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end

  defp package do
    [
      name: :maestro,
      files: ["lib", "mix.exs", "README.md"],
      maintainers: [
        "Neil Menne",
        "Chris Keathley",
        "Brent Spell",
        "Lang Martin"
      ],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @source_url,
        "Docs" => "http://hexdocs.pm/maestro"
      }
    ]
  end
end
