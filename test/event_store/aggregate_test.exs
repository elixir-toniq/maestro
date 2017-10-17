defmodule EventStore.AggregateTest do
  use ExUnit.Case
  import ExUnitProperties
  import EventStore.Generators

  alias EventStore.Command
  alias EventStore.SampleAggregate

  setup do
    Application.put_env(
      :event_store,
      :storage_adapter,
      EventStore.Store.InMemory
    )
    EventStore.Store.InMemory.reset
    HLClock.start_link
    :ok
  end

  describe "command/event lifecycle" do
    property "commands and events without snapshots" do
      check all agg_id <- timestamp(),
        coms           <- commands(agg_id, max_commands: 200) do

        {:ok, pid} = SampleAggregate.start_link(agg_id)
        for com <- coms do
          events = GenServer.call(pid, {:eval_command, com})
          GenServer.call(pid, {:apply_events, events})
        end

        value = GenServer.call(pid, :get_state)
        assert value == (increments(coms) - decrements(coms))
      end
    end

    test "commands, events, and snapshots" do
      {:ok, agg_id} = HLClock.now
      {:ok, pid} = SampleAggregate.start_link(agg_id)

      apply_command(pid, %Command{type: "increment",
                                  sequence: 1,
                                  aggregate_id: agg_id,
                                  data: %{}})

      apply_command(pid, %Command{type: "increment",
                                  sequence: 1,
                                  aggregate_id: agg_id,
                                  data: %{}})

      snapshot = GenServer.call(pid, :get_snapshot)
      EventStore.Store.commit_snapshot(snapshot)

      GenServer.stop(pid)

      {:ok, pid} = SampleAggregate.start_link(agg_id)

      apply_command(pid, %Command{type: "increment",
                                  sequence: 1,
                                  aggregate_id: agg_id,
                                  data: %{}})

      value = GenServer.call(pid, :get_state)
      assert value == 3
    end
  end

  def apply_command(pid, command) do
    events = GenServer.call(pid, {:eval_command, command})
    EventStore.Store.commit_events!(events)
    GenServer.call(pid, {:apply_events, events})
  end

  def increments(commands) do
    commands
    |> Enum.filter(&is_increment/1)
    |> Enum.count()
  end

  def decrements(commands) do
    commands
    |> Enum.filter(&is_decrement/1)
    |> Enum.count()
  end

  defp is_increment(%{type: t}), do: t == "increment"

  defp is_decrement(%{type: t}), do: t == "decrement"
end

