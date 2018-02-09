defmodule Maestro.SampleAggregate do
  @moduledoc """
  Test implementation of an Aggregate behaviour
  """

  use Maestro.Aggregate
  alias Maestro.Schemas.Event

  alias HLClock

  def initial_state, do: 0

  def eval_command(curr, %{type: "increment"}) do
    with {:ok, ts} <- HLClock.now() do
      [
        %Event{
          timestamp: ts,
          aggregate_id: curr.id,
          sequence: curr.sequence + 1,
          body: %{"message" => "increment"}
        }
      ]
    end
  end

  def eval_command(curr, %{type: "decrement"}) do
    with {:ok, ts} <- HLClock.now() do
      [
        %Event{
          timestamp: ts,
          aggregate_id: curr.id,
          sequence: curr.sequence + 1,
          body: %{"message" => "decrement"}
        }
      ]
    end
  end

  def apply_event(v, %{body: %{"message" => "increment"}}), do: v + 1
  def apply_event(v, %{body: %{"message" => "decrement"}}), do: v - 1

  def prepare_snapshot(v), do: %{"value" => v}

  def use_snapshot(_, %{body: %{"value" => v}}), do: v
  def use_snapshot(prev, _snapshot), do: prev
end
