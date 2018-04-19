defmodule Maestro.Aggregate.ProjectionHandler do
  @moduledoc """
  `ProjectionHandler`s are used to manage alternate representations of an
  aggregate.

  This defines a minimal behaviour for use within the aggregate command/event
  lifecycle. For projections that should be updated immediately iff the relevant
  events are committed, a `ProjectionHandler` should indicate this by returning
  true via the `strong?/0` callback.
  """

  @type name :: any()

  @type args :: [any()]

  @type event :: Maestro.Types.Event.t()

  @doc """
  Strong consistency projections are committed along with the events in
  a single transaction. This allows for maintaining projections like secondary
  indices and uniqueness constraints that would be hard to maintain in an async
  projection.
  """
  @callback strong?() :: boolean()

  @doc """
  Given an arbitrary event the projection should always return either named MFA
  triples or nil. This is true for either eventually consistent or strongly
  consistent projections. The function's return type should follow the
  constraints imposed by `Ecto.Multi.run/5` (i.e. returning {:ok, value} or
  {:error, any})
  """
  @callback project(event()) :: {name(), module(), function(), args()} | nil
end
