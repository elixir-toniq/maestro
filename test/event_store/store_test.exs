defmodule EventStore.StoreTest do
  use ExUnit.Case

  import StreamData
  import ExUnitProperties

  import Ecto.Query

  import EventStore.Generators

  alias EventStore.{Repo, Store}
  alias EventStore.Schemas.Event

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  describe "commit_events!" do
    property "no conflict events are committed" do
      check all agg_id <- timestamp(),
        times          <- uniq_list_of(
          timestamp(),
          min_length: 1,
          max_length: 10
        ) do

        # generate matching sequence numbers
        seqs = 1..Enum.count(times)

        # insert the provided records to the database
        times
        |> Enum.zip(seqs)
        |> Enum.map(&(to_event(&1, agg_id)))
        |> Store.commit_events!()

        assert Enum.count(times) == num_events(agg_id)
      end
    end

    property "sequence conflicts are marked for retry" do
      check all agg_id <- timestamp(),
        ts0            <- timestamp(),
        times          <- uniq_list_of(timestamp(), min_length: 1) do

        seqs = 1..Enum.count(times)

        times
        |> Enum.zip(seqs)
        |> Enum.map(&(to_event(&1, agg_id)))
        |> Store.commit_events!()

        e = to_event({ts0, 1}, agg_id)
        {:error, reason} =
          e
          |> List.wrap()
          |> Store.commit_events!()

        assert reason == :retry_command
      end
    end
  end

  def num_events(agg_id) do
    Repo.one!(from e in Event,
      where: e.aggregate_id == ^agg_id,
      select: count(e.aggregate_id))
  end

  def to_event({ts, seq}, agg_id, body \\ %{}),
    do: %EventStore.Schemas.Event{timestamp: ts,
                                  aggregate_id: agg_id,
                                  sequence: seq,
                                  body: body}
end
