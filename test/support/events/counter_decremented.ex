defmodule Maestro.SampleAggregate.Events.CounterDecremented do
  @moduledoc """
  decrement counter event
  """

  @behaviour Maestro.Aggregate.EventHandler

  def apply(state, _), do: state - 1
end
