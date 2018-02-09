defmodule EventStore.Generators do
  @moduledoc """
  Property testing utilities including:
    * HLC Timestamp generator
  """

  import StreamData
  import ExUnitProperties

  alias HLClock.Timestamp

  @max_node_size 18_446_744_073_709_551_615
  @max_counter_size 65_535
  @max_time_size 2_147_483_647

  def int_of_size(size) do
    bind(bitstring(length: size), fn(<<n :: integer-size(size)>>) ->
      constant(n)
    end)
  end

  def timestamp do
    gen all time <- integer(0..max_time()),
      counter <- integer(0..max_counter()),
      node_id <- integer(0..max_node()) do
      {:ok, timestamp} = Timestamp.new(time, counter, node_id)
      timestamp
    end
  end

  def large_time, do: large_integer(max_time())
  def large_node_id, do: large_integer(max_node())
  def large_counter, do: large_integer(max_counter())

  def large_integer(value), do: integer((value + 1)..(value * 2))

  def max_node, do: @max_node_size
  def max_time, do: @max_time_size
  def max_counter, do: @max_counter_size

  def commands(agg_id, opts \\ []) do
    defaults = [max_commands: 10]
    [max_commands: max_commands] = Keyword.merge(defaults, opts)
    gen all com_flags <- list_of(
      boolean(),
      max_length: max_commands,
      min_length: 1) do

      com_flags
      |> Enum.with_index(1)
      |> Enum.map(&to_command(&1, agg_id))
    end
  end

  def to_command({true, seq}, agg_id) do
    %EventStore.Command{
      type: "increment",
      sequence: seq,
      aggregate_id: agg_id,
      data: %{}
    }
  end

  def to_command({false, seq}, agg_id) do
    %EventStore.Command{
      type: "decrement",
      sequence: seq,
      aggregate_id: agg_id,
      data: %{}
    }
  end
end
