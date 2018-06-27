defmodule Maestro.Mixfile do
  use Mix.Project

  @version "0.2.0"
  @source_url "https://github.com/toniqsystems/maestro"

  def project do
    [
      app: :maestro,
      version: @version,
      elixir: "~> 1.6",
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
      dialyzer: [ignore_warnings: "dialyzer.ignore-warnings"],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.html": :test,
        "coveralls.post": :test
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
      {:ecto, "~> 2.2"},
      {:postgrex, ">= 0.0.0"},
      {:poison, "~> 3.0"},
      {:ecto_hlclock, "~> 0.1"},
      {:mock, "~> 0.3", only: :test, runtime: false},
      {:credo, "~> 0.5", only: [:dev, :test]},
      {:stream_data, "~> 0.3", only: [:test]},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:benchee, "~> 0.9", only: :dev},
      {:ex_doc, "~> 0.16", only: :dev},
      {:excoveralls, "~> 0.8", only: :test}
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
      maintainers: ["Neil Menne", "Chris Keathley", "Brent Spell"],
      licenses: ["Apache 2.0"],
      links: %{
        "GitHub" => @source_url,
        "Docs" => "http://hexdocs.pm/maestro"
      }
    ]
  end
end
