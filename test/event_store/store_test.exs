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
        times
        |> Enum.with_index(1)
        |> Enum.map(&(to_event(&1, agg_id)))
        |> Store.commit_events!()

        assert Enum.count(times) == num_events(agg_id)
      end
    end

    property "sequence conflicts are marked for retry" do
      check all agg_id <- timestamp(),
        ts0            <- timestamp(),
        times          <- uniq_list_of(timestamp(), min_length: 1) do

        times
        |> Enum.with_index(1)
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

  describe "get_events" do
    property "returns empty list when no relevant events exist" do
      check all agg_id <- timestamp(),
        times <- uniq_list_of(timestamp()) do

        times
        |> Enum.with_index(1)
        |> Enum.map(&(to_event(&1, agg_id)))
        |> Store.commit_events!()

        assert [] == Store.get_events(agg_id, Enum.count(times) + 1)
      end
    end

    property "returns events otherwise" do
      check all agg_id <- timestamp(),
        times <- uniq_list_of(timestamp(), min_length: 1) do

        total = Enum.count(times)

        times
        |> Enum.with_index(1)
        |> Enum.map(&(to_event(&1, agg_id)))
        |> Store.commit_events!()

        seq = times
        |> Enum.with_index(1)
        |> Enum.random()
        |> elem(1)

        assert agg_id
        |> Store.get_events(seq)
        |> Enum.count() == (total - seq)
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
