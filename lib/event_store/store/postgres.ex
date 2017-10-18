defmodule EventStore.Store.Postgres do
  @behaviour EventStore.Store.Adapter

  import Ecto.Query

  alias Ecto.Multi

  alias EventStore.Repo
  alias EventStore.Schemas.{Event, Snapshot}

  def commit_events!(events) do
    events
    |> Stream.map(&Event.changeset/1)  # ensure valid events are being passed
    |> insert_events
  end

  def commit_snapshot(%Snapshot{} = s) do
    upstmt =
      from s in Snapshot,
      where: fragment("s0.sequence < excluded.sequence"),
      update: [set: [sequence: fragment("excluded.sequence"),
                     body: fragment("excluded.body")]]

    case Repo.insert_all(
          Snapshot,
          for_insert(s),
          conflict_target: [:aggregate_id],
          on_conflict: upstmt
        ) do
      {x, _} when x >= 0 and x <= 1 -> :ok
    end
  end

  def get_events(aggregate_id, seq \\ 0) do
    Repo.all(
      from e in Event,
      where: e.sequence > ^seq,
      where: e.aggregate_id == ^aggregate_id,
      select: e
    )
  end

  def get_snapshot(
    aggregate_id,
    seq \\ 0
  ) do
    Repo.one(
      from s in Snapshot,
      where: s.sequence > ^seq,
      where: s.aggregate_id == ^aggregate_id,
      select: s
    )
  end

  defp insert_events(changesets) do
    changesets
    |> Enum.reduce(Multi.new, &append_changeset/2)
    |> Repo.transaction()
    |> case do
         {:error, _multi_key, _cs, _res} = err -> retry_error(err)
         {:ok, %{} = res} -> Map.values(res)
       end
  end

  defp append_changeset(cs, mult),
    do: Multi.insert(mult, changeset_key(cs), cs, returning: true)

  defp retry_error({:error, _, %{errors: [sequence: {:dupe_seq_agg, _}]}, _}),
    do: {:error, :retry_command}
  defp retry_error(err), do: raise EventStore.StoreError.exception(err)

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
