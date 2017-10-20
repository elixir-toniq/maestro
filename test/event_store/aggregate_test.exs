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

        for com <- coms do
          apply_command(com)
        end

        value = SampleAggregate.call(agg_id, :get_state)
        assert value == (increments(coms) - decrements(coms))
      end
    end

    test "commands, events, and snapshots" do
      {:ok, pid, agg_id} = SampleAggregate.new()

      assert 0 == SampleAggregate.call(agg_id, :get_state)

      apply_command(%Command{type: "increment",
                             sequence: 1,
                             aggregate_id: agg_id,
                             data: %{}})

      apply_command(%Command{type: "increment",
                             sequence: 1,
                             aggregate_id: agg_id,
                             data: %{}})

      snapshot = SampleAggregate.call(agg_id, :get_snapshot)
      EventStore.Store.commit_snapshot(snapshot)

      GenServer.stop(pid)

      {:ok, _pid} = SampleAggregate.start_link(agg_id)

      apply_command(%Command{type: "increment",
                             sequence: 1,
                             aggregate_id: agg_id,
                             data: %{}})

      assert 3 = SampleAggregate.call(agg_id, :get_state)
    end

    test "recover an intermediate state" do
      {:ok, _pid, agg_id} = SampleAggregate.new()

      base_command = %Command{type: "increment",
                              sequence: 1,
                              aggregate_id: agg_id,
                              data: %{}}

      commands =
        base_command
        |> repeat(10)
        |> Enum.with_index(1)
        |> Enum.map(fn ({c, i}) -> %{c | sequence: i} end)

      for com <- commands, do: apply_command(com)

      assert 2 == SampleAggregate.call(agg_id, {:get_state, 2})
      assert 10 == SampleAggregate.call(agg_id, :get_state)
    end
  end

  def repeat(val, times) do
    Enum.map(0..(times - 1), fn (_) -> val end)
  end

  def apply_command(command) do
    SampleAggregate.call(command.aggregate_id, {:eval_command, command})
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

