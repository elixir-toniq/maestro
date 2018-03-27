defmodule Maestro.Store do
  @moduledoc """
  Concise API for events and snapshots. Requires a Repo to operate.
  """

  @default_options [max_sequence: 2_147_483_647]

  @type id :: HLClock.Timestamp.t()

  @type sequence :: non_neg_integer()

  @type event :: Maestro.Types.Event.t()

  @type events :: [event()]

  @type snapshot :: Maestro.Types.Snapshot.t()

  @type opts :: [{:max_sequence, sequence()}]

  @doc """
  Commit the events provided iff there is no sequence number conflict.
  Otherwise, the command should be retried as indicated by the specific error
  tuple.
  """
  @spec commit_events(events()) :: :ok | {:error, :retry_command}
  def commit_events(events) do
    adapter().commit_events(events)
  end

  @doc """
  Store the snapshot iff the sequence number is greater than what is in the
  store. This allows nodes that are partitioned from each other to treat the
  store as the source of truth even when writing snapshots.
  """
  @spec commit_snapshot(snapshot()) :: :ok
  def commit_snapshot(snapshot) do
    adapter().commit_snapshot(snapshot)
  end

  @doc """
  Retrieve all events for a specific aggregate by id and minimum sequence number.

  Options include:
  * `:max_sequence` - useful hydration purposes (defaults to `max_sequence/0`)
  """
  @spec get_events(id(), sequence(), opts()) :: events()
  def get_events(aggregate_id, seq, opts \\ []) do
    options =
      @default_options
      |> Keyword.merge(opts)
      |> Enum.into(%{})

    adapter().get_events(aggregate_id, seq, options)
  end

  @doc """
  Retrieve a snapshot by aggregate id and minimum sequence number. If no
  snapshot is found, nil is returned.

  Options include:
  * `:max_sequence` - useful hydration purposes (defaults to `max_sequence/0`)
  """
  @spec get_snapshot(id(), sequence(), opts()) :: snapshot() | nil
  def get_snapshot(aggregate_id, seq, opts \\ []) do
    options =
      @default_options
      |> Keyword.merge(opts)
      |> Enum.into(%{})

    adapter().get_snapshot(aggregate_id, seq, options)
  end

  defp adapter do
    Application.get_env(:maestro, :storage_adapter, Maestro.Store.InMemory)
  end

  @doc """
  Return the maximum allowable sequence number permitted by the durable storage
  adapter.
  """
  @spec max_sequence :: non_neg_integer()
  def max_sequence, do: @default_options[:max_sequence]
end
