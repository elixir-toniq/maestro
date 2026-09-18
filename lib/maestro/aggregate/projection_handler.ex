defmodule Maestro.Aggregate.ProjectionHandler do
  @moduledoc """
  `ProjectionHandler`s are used to manage alternate representations of an
  aggregate.

  This defines a minimal behaviour for use within the aggregate command/event
  lifecycle. For projections that should be updated immediately iff the relevant
  events are committed, the relevant `ProjectionHandler` should by included in
  the list of `:projections` on the aggregate root.
  """

  @type event :: Maestro.Types.Event.t()
  @type repo :: module() | nil

  @doc """
  Projections registered with an aggregate root are invoked for _every_ event,
  so they should ignore unrelated events explicitly.

  Like command handlers, a projection can reject the change by returning
  `{:error, reason}`, which rolls back the event's transaction. Any other return
  value allows the commit to proceed. Raising also rolls back the transaction.
  """
  @callback project(repo(), event()) :: value :: any()
end
