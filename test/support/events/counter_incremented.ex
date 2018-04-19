defmodule Maestro.SampleAggregate.Events.CounterIncremented do
  @moduledoc """
  increment counter event
  """

  @behaviour Maestro.Aggregate.EventHandler

  defp inc(v), do: v + 1

  def apply(state, _), do: Map.update!(state, "value", &inc/1)
end
