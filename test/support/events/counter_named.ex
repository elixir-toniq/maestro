defmodule Maestro.SampleAggregate.Events.CounterNamed do
  @moduledoc """
  Counter was able to successfully claim the name, so update state
  """

  @behaviour Maestro.Aggregate.EventHandler

  def apply(state, %{body: %{"name" => new_name}}) do
    Map.put(state, "name", new_name)
  end
end
