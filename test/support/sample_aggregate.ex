defmodule Maestro.SampleAggregate do
  @moduledoc """
  Test implementation of an Aggregate behaviour
  """

  use Maestro.Aggregate.Root,
    command_prefix: Maestro.SampleAggregate.Commands,
    event_prefix: Maestro.SampleAggregate.Events

  alias HLClock

  def initial_state, do: 0

  def prepare_snapshot(v), do: %{"value" => v}

  def use_snapshot(_, %{body: %{"value" => v}}), do: v
end
