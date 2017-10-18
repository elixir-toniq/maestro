defmodule EventStore.Store.Adapter do
  alias EventStore.Schemas.{Event, Snapshot}

  @type id :: Event.aggregate_id

  @type seq :: Event.sequence

  @callback commit_events!([Event.t]) :: [Event.t]
                                       | {:error, :retry_command}
                                       | :no_return

  @callback commit_snapshot(Snapshot.t) :: :ok | :no_return

  @callback get_events(id, seq) :: [Event.t]

  @callback get_snapshot(id, seq) :: nil | Snapshot.t
end
