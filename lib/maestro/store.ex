defmodule Maestro.Store do
  @moduledoc """
  Concise API for events and snapshots. Requires a Repo to operate.
  """

  @default_options [max_sequence: 2_147_483_647]

  def commit_events(events) do
    adapter().commit_events(events)
  end

  def commit_snapshot(snapshot) do
    adapter().commit_snapshot(snapshot)
  end

  def get_events(aggregate_id, seq, opts \\ []) do
    options =
      @default_options
      |> Keyword.merge(opts)
      |> Enum.into(%{})
    adapter().get_events(aggregate_id, seq, options)
  end

  def get_snapshot(aggregate_id, seq, opts \\ []) do
    options =
      @default_options
      |> Keyword.merge(opts)
      |> Enum.into(%{})
    adapter().get_snapshot(aggregate_id, seq, options)
  end

  defp adapter do
    Application.get_env(
      :maestro, :storage_adapter, Maestro.Store.InMemory)
  end

  def max_sequence, do: @default_options[:max_sequence]
end
