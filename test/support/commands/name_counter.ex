defmodule Maestro.SampleAggregate.Commands.NameCounter do
  @moduledoc """
  Provides a naive implementation of claiming a unique name.

  This is only feasible with the strong projections in place to enforce the
  unique name constraint.
  """

  @behaviour Maestro.Aggregate.CommandHandler

  alias Maestro.InvalidCommandError
  alias Maestro.Types.Event

  def eval(%{state: %{"name" => cur}}, _command) when is_binary(cur) do
    raise InvalidCommandError, "altering names is prohibited"
  end

  def eval(aggregate, %{data: %{"name" => new_name}}) do
    [
      %Event{
        aggregate_id: aggregate.id,
        type: "counter_named",
        body: %{"name" => new_name}
      }
    ]
  end
end
