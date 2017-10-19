defmodule EventStore.Aggregate.Supervisor do
  @moduledoc """
  All aggregate roots, no matter how many different kinds you may have, are
  managed by a single supervisor/registry (for now). Given that aggregates are
  independently configurable and extensible, the need for a 1:1 on supervisors
  per aggregate is a premature optimization. Furthermore, aggregate IDs are HLC
  timestamps and are thus unique even across aggregates.
  """

  use Supervisor

  alias EventStore.Aggregate

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def get_child(key, module) do
    case Supervisor.start_child(__MODULE__, [key, module]) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end
  end

  def init(_args) do
    child = Supervisor.child_spec(
      Aggregate,
      start: {Aggregate, :start_link, []}
    )

    Supervisor.init([child], strategy: :simple_one_for_one)
  end
end
