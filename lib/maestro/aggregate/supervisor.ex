defmodule Maestro.Aggregate.Supervisor do
  @moduledoc """
  All aggregate roots, no matter how many different kinds you may have, are
  managed by a single supervisor/registry (for now). Given that aggregates are
  independently configurable and extensible, the need for a 1:1 on supervisors
  per aggregate is a premature optimization. Furthermore, aggregate IDs are HLC
  timestamps and are thus unique even across aggregates.
  """

  use DynamicSupervisor

  alias Maestro.Aggregate.Root

  def start_link(args) do
    DynamicSupervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def get_child(key, mod) do
    spec = {Root, aggregate_id: key, module: mod}

    case DynamicSupervisor.start_child(__MODULE__, spec) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end
  end

  def init(_args) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
