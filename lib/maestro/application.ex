defmodule Maestro.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {HLClock, hlc_opts()},
      {Registry, keys: :unique, name: Maestro.Aggregate.Registry},
      {Maestro.Aggregate.Supervisor, []}
    ]

    opts = [strategy: :one_for_all, name: __MODULE__]
    Supervisor.start_link(children, opts)
  end

  defp hlc_opts do
    case Application.get_env(:maestro, :node_id) do
      nil -> [name: :maestro_hlc]
      node_id -> [name: :maestro_hlc, node_id: node_id]
    end
  end
end
