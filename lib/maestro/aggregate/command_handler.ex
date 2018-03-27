defmodule Maestro.Aggregate.CommandHandler do
  @moduledoc """
  Simple behaviour for properly implementing command handlers the way that
  maestro expects. Its use is not required but is encouraged.
  """

  @type root :: Maestro.Aggregate.Root.t()
  @type command :: Maestro.Types.Command.t()
  @type event :: Maestro.Types.Event.t()

  @doc """
  Command handlers in maestro should implement an `eval` function that expects
  to receive the current `Root` object complete with sequence number and
  aggregate ID and the incoming command. They should return either a list of
  zero or more events or an error tuple.
  """
  @callback eval(root(), command()) :: [event()] | {:error, atom()}
end
