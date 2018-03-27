defmodule Maestro.SampleAggregate.Events.CounterIncremented do
  @moduledoc """
  increment counter event
  """

  @behaviour Maestro.Aggregate.EventHandler

  def apply(state, _), do: state + 1
end
