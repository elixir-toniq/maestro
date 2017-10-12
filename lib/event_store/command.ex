defmodule EventStore.Command do
  @moduledoc """
  TODO: put best words here
  """

  # @type t :: [command: String.t,
  #             entity_id: HLClock.Timestamp.t,
  #             sequence: integer,
  #             data: map]
  defstruct [:type, :entity_id, :sequence, :data]

  @callback handle_command(Command.t) :: any

  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)

      def handle_command(_), do: {:error, :unhandled_command}
      defoverridable [handle_command: 1]
    end
  end

  defmacro command(name, module) do
    quote do
      def eval_command(%{command: unquote(name)} = command) do
        unquote(module).handle_command(command)
      end
    end
  end
end
