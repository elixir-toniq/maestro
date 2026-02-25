defmodule Maestro.Aggregate.CommandHandler do
  @moduledoc """
  Simple behaviour for properly implementing command handlers the way that
  maestro expects. Its use is not required but is encouraged.
  """

  @type root :: Maestro.Aggregate.Root.t()
  @type command :: Maestro.Types.Command.t()
  @type uncommitted_event :: Maestro.Types.Event.uncommitted()

  @doc """
  Command handlers in maestro should implement an `eval` function that expects
  to receive the current `Root` object complete with sequence number and
  aggregate ID and the incoming command. They should return `{:ok, events}` on
  success or `{:error, reason}` to reject the command.
  """
  @callback eval(root(), command()) ::
              {:ok, [uncommitted_event()]} | {:error, any()}
end
