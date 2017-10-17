defmodule EventStore.Store.InMemory do
  use GenServer
  @behaviour EventStore.Store.Adapter

  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    {:ok, %{events: [], snapshots: []}}
  end

  def commit_events!(events) do
    GenServer.call(__MODULE__, {:commit_events, events})
  end

  def commit_snapshot(snapshot) do
    GenServer.call(__MODULE__, {:commit_snapshot, snapshot})
  end

  def get_events(id, seq \\ 0) do
    GenServer.call(__MODULE__, {:get_events, id, seq})
  end

  def get_snapshot(id, seq \\ 0) do
    GenServer.call(__MODULE__, {:get_snapshot, id, seq})
  end

  def reset, do: GenServer.call(__MODULE__, :reset)

  def handle_call({:commit_events, new_events}, _from, state) do
    if overlapping?(state.events, new_events) do
      {:reply, {:error, :retry_command}, state}
    else
      {:reply, {:ok, new_events}, %{state | events: state.events ++ new_events}}
    end
  end

  def handle_call({:commit_snapshot, snapshot}, _from, state) do
    new_snapshots = [snapshot | state.snapshots]
    {:reply, :ok, %{state | snapshots: new_snapshots}}
  end

  def handle_call({:get_events, id, seq}, _from, state) do
    events = Enum.filter(state.events, & included?(&1, id, seq))
    {:reply, events, state}
  end

  def handle_call({:get_snapshot, id, seq}, _from, state) do
    snapshot = Enum.find(state.snapshots, & included?(&1, id, seq))
    {:reply, {:ok, snapshot}, state}
  end

  def handle_call(:reset, _from, _state) do
    {:reply, :ok, %{events: [], snapshots: []}}
  end

  defp overlapping?(old_events, new_events) do
    max = Enum.max_by(old_events, &sequence/1, fn -> 1 end)
    min = Enum.min_by(new_events, &sequence/1, fn -> 1 end)
    max >= min
  end

  defp sequence(%{sequence: sequence}), do: sequence

  defp included?(aggregate, id, seq) do
    aggregate.aggregate_id == id && aggregate.sequence > seq
  end
end
