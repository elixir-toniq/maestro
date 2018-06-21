defmodule Maestro.SampleAggregate.Commands.IncrementCounter do
  @moduledoc """
  increment counter command
  """

  alias Maestro.Types.Event

  @behaviour Maestro.Aggregate.CommandHandler

  def eval(aggregate, _command) do
    [
      %Event{
        aggregate_id: aggregate.id,
        type: "counter_incremented",
        body: %{"message" => "increment"}
      }
    ]
  end
end
