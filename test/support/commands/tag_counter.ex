defmodule Maestro.SampleAggregate.Commands.TagCounter do
  @moduledoc """
  Emits one event per new tag, using atom keys in the body to verify
  normalization through the store.
  """

  @behaviour Maestro.Aggregate.CommandHandler

  alias Maestro.Types.Event

  def eval(%{id: id, state: %{"tags" => existing}}, %{data: %{"tags" => tags}}) do
    events =
      tags
      |> Enum.reject(&(&1 in existing))
      |> Enum.map(fn tag ->
        %Event{aggregate_id: id, type: "counter_tagged", body: %{tag: tag}}
      end)

    {:ok, events}
  end
end
