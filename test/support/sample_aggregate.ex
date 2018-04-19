defmodule Maestro.SampleAggregate do
  @moduledoc """
  Test implementation of an Aggregate behaviour
  """

  use Maestro.Aggregate.Root,
    command_prefix: Maestro.SampleAggregate.Commands,
    event_prefix: Maestro.SampleAggregate.Events,
    projectors: [Maestro.SampleAggregate.Projections.NameProjectionHandler]

  alias HLClock

  def initial_state, do: %{"value" => 0, "name" => nil}

  def prepare_snapshot(state), do: state

  def use_snapshot(_, %{body: state}), do: state
end
