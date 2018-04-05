defmodule Maestro.AggregateTest do
  use ExUnit.Case
  import ExUnitProperties
  import Maestro.Generators
  import Mock

  alias DBConnection.ConnectionError
  alias HLClock.Server, as: HLCServer
  alias Maestro.{InvalidCommandError, InvalidHandlerError}
  alias Maestro.Aggregate.Root
  alias Maestro.Types.Command
  alias Maestro.SampleAggregate
  alias Maestro.Store.InMemory

  setup_all do
    Application.put_env(
      :maestro,
      :storage_adapter,
      Maestro.Store.InMemory
    )

    {:ok, pid} = InMemory.start_link()
    HLCServer.start_link()

    on_exit(fn ->
      Process.exit(pid, :normal)
    end)

    :ok
  end

  describe "command/event lifecycle" do
    property "commands and events without snapshots" do
      check all agg_id <- timestamp(),
                coms <- commands(agg_id, max_commands: 200) do
        for com <- coms do
          :ok = SampleAggregate.evaluate(agg_id, com)
        end

        {:ok, value} = SampleAggregate.get(agg_id)
        assert value == increments(coms) - decrements(coms)

        {:ok, value} = SampleAggregate.fetch(agg_id)
        assert value == increments(coms) - decrements(coms)
      end
    end

    test "commands, events, and snapshots" do
      {:ok, pid, agg_id} = SampleAggregate.new()

      {:ok, value} = SampleAggregate.get(agg_id)
      assert value == 0

      SampleAggregate.evaluate(agg_id, %Command{
        type: "increment_counter",
        sequence: 1,
        aggregate_id: agg_id,
        data: %{}
      })

      SampleAggregate.evaluate(agg_id, %Command{
        type: "increment_counter",
        sequence: 1,
        aggregate_id: agg_id,
        data: %{}
      })

      SampleAggregate.snapshot(agg_id)

      GenServer.stop(pid)

      {:ok, _pid} = SampleAggregate.start_link(agg_id)

      SampleAggregate.evaluate(agg_id, %Command{
        type: "increment_counter",
        sequence: 1,
        aggregate_id: agg_id,
        data: %{}
      })

      {:ok, value} = SampleAggregate.get(agg_id)
      assert value == 3
    end

    test "recover an intermediate state" do
      {:ok, _pid, agg_id} = SampleAggregate.new()

      base_command = %Command{
        type: "increment_counter",
        sequence: 1,
        aggregate_id: agg_id,
        data: %{}
      }

      commands =
        base_command
        |> repeat(10)
        |> Enum.with_index(1)
        |> Enum.map(fn {c, i} -> %{c | sequence: i} end)

      for com <- commands do
        :ok = SampleAggregate.evaluate(agg_id, com)
      end

      assert SampleAggregate.replay(agg_id, 2) == {:ok, 2}
      assert SampleAggregate.get(agg_id) == {:ok, 10}
    end
  end

  describe "communicating/handling failure" do
    test "invalid command" do
      {:ok, _pid, agg_id} = SampleAggregate.new()

      com = %Command{
        type: "invalid",
        sequence: 0,
        aggregate_id: agg_id,
        data: %{}
      }

      {:error, err, _stack} = SampleAggregate.evaluate(agg_id, com)

      assert err == InvalidHandlerError.exception(type: "invalid")
    end

    test "handler rejected command" do
      {:ok, _pid, agg_id} = SampleAggregate.new()

      com = %Command{
        type: "conditional_increment",
        sequence: 0,
        aggregate_id: agg_id,
        data: %{"do_inc" => false}
      }

      {:error, err, _stack} = SampleAggregate.evaluate(agg_id, com)

      assert err ==
               InvalidCommandError.exception(
                 message: "command incorrectly specified"
               )
    end

    test "handler raised an unexpected error" do
      {:ok, _pid, agg_id} = SampleAggregate.new()

      com = %Command{
        type: "raise_command",
        sequence: 0,
        aggregate_id: agg_id,
        data: %{"raise" => true}
      }

      {:error, err, _stack} = SampleAggregate.evaluate(agg_id, com)

      assert err ==
               ArgumentError.exception(
                 message: "commands can raise arbitrary exceptions as well"
               )
    end

    test "store error" do
      {:ok, _pid, agg_id} = SampleAggregate.new()

      com = %Command{
        type: "increment_counter",
        sequence: 2,
        aggregate_id: agg_id,
        data: %{}
      }

      with_mock Maestro.Store,
        get_snapshot: fn _, _, _ ->
          raise(ConnectionError, "some")
        end do
        {:error, err, _stack} = SampleAggregate.evaluate(agg_id, com)
        assert err == ConnectionError.exception("some")
      end
    end
  end

  test "event_type/2" do
    assert Root.event_type(Maestro.SampleAggregate.Events, %{
             __struct__: Maestro.SampleAggregate.Events.TypedEvent.Completed
           }) == "typed_event.completed"
  end

  def repeat(val, times) do
    Enum.map(0..(times - 1), fn _ -> val end)
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

  defp is_increment(%{type: t}), do: t == "increment_counter"

  defp is_decrement(%{type: t}), do: t == "decrement_counter"
end
