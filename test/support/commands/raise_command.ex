defmodule Maestro.SampleAggregate.Commands.RaiseCommand do
  @moduledoc false

  @behaviour Maestro.Aggregate.CommandHandler

  def eval(_aggregate, %{data: %{"raise" => _any}}) do
    raise ArgumentError, "commands can raise arbitrary exceptions as well"
  end
end
