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

  @doc """
  Projections registered with an aggregate root are invoked for _every_ event,
  so they should ignore unrelated events explicitly.
  """
  @callback project(event()) :: value :: any()
end
