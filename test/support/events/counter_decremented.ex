defmodule Maestro.SampleAggregate.Events.CounterDecremented do
  @moduledoc """
  decrement counter event
  """

  @behaviour Maestro.Aggregate.EventHandler

  defp dec(v), do: v - 1

  def apply(state, _), do: Map.update!(state, "value", &dec/1)
end
