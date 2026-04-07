defmodule Maestro.SampleAggregate.Events.CounterTagged do
  @moduledoc """
  Appends a tag to the aggregate's tag list, using string keys matching
  the normalized (committed) form of the event body.
  """

  @behaviour Maestro.Aggregate.EventHandler

  def apply(%{"tags" => tags} = state, %{body: %{"tag" => tag}}) do
    Map.put(state, "tags", tags ++ [tag])
  end
end
