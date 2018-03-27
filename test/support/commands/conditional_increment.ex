defmodule Maestro.SampleAggregate.Commands.ConditionalIncrement do
  @moduledoc false

  @behaviour Maestro.Aggregate.CommandHandler

  alias Maestro.InvalidCommandError

  def eval(_aggregate, _com) do
    raise InvalidCommandError, "command incorrectly specified"
  end
end
