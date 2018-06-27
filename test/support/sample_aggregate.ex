defmodule Maestro.SampleAggregate do
  @moduledoc """
  Test implementation of an Aggregate behaviour
  """

  use Maestro.Aggregate.Root,
    command_prefix: Maestro.SampleAggregate.Commands,
    event_prefix: Maestro.SampleAggregate.Events,
    projections: [Maestro.SampleAggregate.Projections.NameProjectionHandler]

  def initial_state, do: %{"value" => 0, "name" => nil}

  def prepare_snapshot(state), do: state

  def use_snapshot(_, %{body: state}), do: state
end
