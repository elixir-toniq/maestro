defmodule Maestro.Application do
  @moduledoc false

  use Application

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      supervisor(Maestro.Repo, []),
      worker(Maestro.Store.InMemory, []),
      {Maestro.AggregateSupervisor, []}
    ]

    opts = [strategy: :one_for_one, name: Maestro.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
