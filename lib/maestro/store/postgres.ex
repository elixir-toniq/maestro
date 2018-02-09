defmodule Maestro.Store.Postgres do
  @moduledoc """
  Ecto+Postgres implementation of the storage mechanism.

  Events are never replayed outside of the aggregate's context, so the
  implementation doesn't support retrieval without an aggregate ID.
  """

  @behaviour Maestro.Store.Adapter

  import Ecto.Query

  alias Ecto.Multi

  alias Maestro.Repo
  alias Maestro.Schemas.{Event, Snapshot}

  def commit_events(events) do
    # ensure valid events are being passed
    events
    |> Enum.map(&Event.changeset/1)
    |> insert_events()
  end

  def commit_snapshot(%Snapshot{} = s) do
    upstmt =
      from(
        s in Snapshot,
        where: fragment("s0.sequence < excluded.sequence"),
        update: [
          set: [
            sequence: fragment("excluded.sequence"),
            body: fragment("excluded.body")
          ]
        ]
      )

    case Repo.insert_all(
           Snapshot,
           for_insert(s),
           conflict_target: [:aggregate_id],
           on_conflict: upstmt
         ) do
      {x, _} when x >= 0 and x <= 1 -> :ok
    end
  end

  def get_events(aggregate_id, min_seq, %{max_sequence: max_seq}) do
    event_query()
    |> bounded_sequence(min_seq, max_seq)
    |> for_aggregate(aggregate_id)
    |> Repo.all()
  end

  def get_snapshot(aggregate_id, min_seq, %{max_sequence: max_seq}) do
    snapshot_query()
    |> bounded_sequence(min_seq, max_seq)
    |> for_aggregate(aggregate_id)
    |> Repo.one()
  end

  defp event_query, do: from(e in Event)

  defp snapshot_query, do: from(s in Snapshot)

  defp bounded_sequence(query, min_seq, max_seq) do
    from(
      r in query,
      where: r.sequence > ^min_seq,
      where: r.sequence <= ^max_seq
    )
  end

  defp for_aggregate(query, agg_id) do
    from(
      r in query,
      where: r.aggregate_id == ^agg_id,
      select: r
    )
  end

  defp insert_events([]), do: :ok

  defp insert_events(changesets) do
    changesets
    |> Enum.reduce(Multi.new(), &append_changeset/2)
    |> Repo.transaction()
    |> case do
      {:error, _, %{errors: [sequence: {:dupe_seq_agg, _}]}, _} ->
        {:error, :retry_command}

      {:ok, _} ->
        :ok
    end
  end

  defp append_changeset(cs, mult), do: Multi.insert(mult, changeset_key(cs), cs)

  defp changeset_key(cs) do
    "#{cs.data.aggregate_id}:#{cs.data.sequence}"
  end

  defp for_insert(%{} = struct) do
    struct
    |> Map.from_struct()
    |> Map.delete(:__meta__)
    |> List.wrap()
  end
end
