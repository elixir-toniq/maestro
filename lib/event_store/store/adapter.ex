defmodule EventStore.Store.Adapter do
  @moduledoc """
  Defines the minimal API for a well-behaved storage implementation.
  """
  alias EventStore.Schemas.{Event, Snapshot}

  @type id :: Event.aggregate_id

  @type seq :: Event.sequence

  @type options :: map

  @doc """
  Events are validated according to the `Event.changeset/1` function. If
  successful, events are committed transactionally. In the event of a conflict
  on sequence number, the storage mechanism should indicate that the command
  _could be_ retried by returning `{:error, :retry_command}`. The `Aggregate`'s
  command lifecycle will see the conflict and update the aggregate's state
  before attempting to evaluate the command again. This allows for making
  stricter evaluation rules for commands. If the events could not be committed
  for any other reason, the storage mechanism should raise an appropriate
  exception.
  """
  @callback commit_events!([Event.t]) :: :ok
                                       | {:error, :retry_command}
                                       | :no_return

  @doc """
  Snapshots are committed iff the proposed version is newer than the version
  already stored. This allows disconnected nodes to optimistically write their
  snapshots and still have a single version stored without conflicts.
  """
  @callback commit_snapshot(Snapshot.t) :: :ok | :no_return

  @doc """
  Events are retrieved by aggregate_id and with at least a minimum sequence
  number, `seq`.

  Additional option(s):
     * `:max_sequence` (integer): a hard upper limit on the sequence number.
       This is useful when attempting to recreate a past state of an aggregate.
  """
  @callback get_events(id, seq, options) :: [Event.t]

  @doc """
  Snapshots can also be retrieved by aggregate_id and with at least a minimum
  sequence number, `seq`.

  Additional option(s):
  * `:max_sequence` (integer): a hard upper limit on the sequence number.
  This is useful when attempting to recreate a past state of an aggregate.
  """
  @callback get_snapshot(id, seq, options) :: nil | Snapshot.t
end
