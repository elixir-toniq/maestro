defmodule EventStore.Commands do
  @moduledoc """
  Commands must be registered via `command/2`
  """

  defmacro command(name, module) do
    quote do
      def eval_command(%{"command" => unquote(name)} = command) do
        unquote(module).handle_command(command)
      end
    end
  end

  defmacro __using__(_) do
    quote do
      def dispatch(command) do
        eval_command(command)
      end
    end
  end
end
