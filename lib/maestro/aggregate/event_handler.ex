defmodule Maestro.Aggregate.EventHandler do
  @moduledoc """
  Minimal behaviour for a proper event handler. Like the `CommandHandler`, the
  use of the behaviour is not strictly required.
  """

  @type event :: Maestro.Types.Event.t()

  @doc """
  Event handlers must succeed in their application of the event.
  Validation and other forms of rejection/failure should be done in the command
  handler. This is made evident in the spec for `apply` in that the result
  should always be a new valid state.
  """
  @callback apply(any(), event()) :: any()
end
