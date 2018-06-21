defmodule Maestro.SampleAggregate.Commands.DecrementCounter do
  @moduledoc """
  decrement counter command
  """

  alias HLClock
  alias Maestro.Types.Event

  @behaviour Maestro.Aggregate.CommandHandler

  def eval(aggregate, _command) do
    [
      %Event{
        aggregate_id: aggregate.id,
        type: "counter_decremented",
        body: %{"message" => "decrement"}
      }
    ]
  end
end
