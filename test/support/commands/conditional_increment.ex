defmodule Maestro.SampleAggregate.Commands.ConditionalIncrement do
  @moduledoc false

  @behaviour Maestro.Aggregate.CommandHandler

  def eval(_aggregate, _com) do
    {:error, :incorrectly_specified}
  end
end
