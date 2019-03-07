defmodule Maestro.Store.Postgres do
  @moduledoc """
  Ecto+Postgres implementation of the storage mechanism.

  Events are never replayed outside of the aggregate's context, so the
  implementation doesn't support retrieval without an aggregate ID.
  """

  @behaviour Maestro.Store.Adapter

  import Ecto.Query

  alias Ecto.Multi
  alias Maestro.Types.{Event, Snapshot}

  def commit_all(events, projections) do
    events
    |> Stream.map(&Event.changeset/1)
    |> Enum.reduce(Multi.new(), &append_changeset/2)
    |> with_projections(events, projections)
    |> apply_all()
  end

  def commit_events(events), do: commit_all(events, [])

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

    repo = get_repo()

    case repo.insert_all(
           Snapshot,
           for_insert(s),
           conflict_target: [:aggregate_id],
           on_conflict: upstmt
         ) do
      {x, _} when x >= 0 and x <= 1 -> :ok
    end
  end

  def get_events(aggregate_id, min_seq, %{max_sequence: max_seq}) do
    repo = get_repo()

    event_query()
    |> bounded_sequence(min_seq, max_seq)
    |> ordered()
    |> for_aggregate(aggregate_id)
    |> repo.all()
  end

  def get_snapshot(aggregate_id, min_seq, %{max_sequence: max_seq}) do
    repo = get_repo()

    snapshot_query()
    |> bounded_sequence(min_seq, max_seq)
    |> for_aggregate(aggregate_id)
    |> repo.one()
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

  defp ordered(query) do
    from(
      r in query,
      order_by: r.timestamp
    )
  end

  defp apply_all(multi) do
    repo = get_repo()

    multi
    |> repo.transaction()
    |> case do
      {:error, _, %{errors: [sequence: {"dupe_seq_agg", _}]}, _} ->
        {:error, :retry_command}

      {:error, _name, err, _changes_so_far} ->
        raise err

      {:ok, _} ->
        :ok
    end
  end

  defp with_projections(multi, _events, []), do: multi

  defp with_projections(multi, events, projections) do
    Multi.run(multi, :projections, fn _repo, _completed ->
      run_projections(events, projections)
    end)
  end

  defp run_projections(events, projections) do
    for handler <- projections,
        event <- events,
        do: handler.project(event)

    {:ok, :ok}
  rescue
    e -> {:error, e}
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

  defp get_repo, do: Application.fetch_env!(:maestro, :repo)
end
