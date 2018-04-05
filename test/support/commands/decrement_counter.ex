defmodule Maestro.SampleAggregate.Commands.DecrementCounter do
  @moduledoc """
  decrement counter command
  """

  alias HLClock
  alias Maestro.Types.Event

  @behaviour Maestro.Aggregate.CommandHandler

  def eval(aggregate, _command) do
    with {:ok, ts} <- HLClock.now() do
      [
        %Event{
          timestamp: ts,
          aggregate_id: aggregate.id,
          sequence: aggregate.sequence + 1,
          type: "counter_decremented",
          body: %{"message" => "decrement"}
        }
      ]
    end
  end
end
