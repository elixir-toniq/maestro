defmodule EventStore.Aggregate.Supervisor do
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
    child = Supervisor.child_spec(Aggregate, start: {Aggregate, :start_link, []})

    Supervisor.init([child], strategy: :simple_one_for_one)
  end
end
