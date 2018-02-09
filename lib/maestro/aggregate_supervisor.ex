defmodule Maestro.AggregateSupervisor do
  @moduledoc """
  Simple supervisor that ensures that should the registry or the aggregate
  supervisor go down, things are brought back up cleanly.
  """

  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    children = [
      {Registry, keys: :unique, name: Maestro.Aggregate.Registry},
      {Maestro.Aggregate.Supervisor, []},
    ]

    opts = [strategy: :one_for_all]

    Supervisor.init(children, opts)
  end
end
