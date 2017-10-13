defmodule EventStore.Store do
  @moduledoc """
  Concise API for events and snapshots. Requires a Repo to operate.
  """

  import Ecto.Query

  alias Ecto.Multi

  alias EventStore.Repo
  alias EventStore.Schemas.{Event, Snapshot}

  def commit_events!(events) do
    events
    |> Stream.map(&Event.changeset/1)  # ensure valid events are being passed
    |> insert_events
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

  defp retry_error({:error, _, %{errors: [sequence: {:dupe_seq_agg, _}]}, _}),
    do: {:error, :retry_command}
  defp retry_error(err), do: raise EventStore.StoreError.exception(err)

  defp append_changeset(cs, mult),
    do: Multi.insert(mult, changeset_key(cs), cs, returning: true)

  defp changeset_key(cs) do
    "#{cs.data.aggregate_id}:#{cs.data.sequence}"
  end

  def commit_snapshot(%Snapshot{} = s) do
    upstmt =
      from s in Snapshot,
      where: fragment("s0.sequence < excluded.sequence"),
      update: [set: [sequence: fragment("excluded.sequence"),
                     body: fragment("excluded.body")]]

    case Repo.insert_all(
          [s],
          conflict_target: [:aggregate_id],
          on_conflict: upstmt
        ) do
      val -> val
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
end

defmodule EventStore.StoreError do
  @moduledoc """
  Raised when a transaction could not be completed and the error is one unsafe
  for our explicit retry path.
  """
  defexception [:error, :message]

  def exception(err) do
    IO.inspect(err)
    %__MODULE__{error: err, message: "unhandled ecto error"}
  end
end
