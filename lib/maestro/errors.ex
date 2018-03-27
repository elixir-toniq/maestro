defmodule Maestro.InvalidHandlerError do
  @moduledoc """
  An exception that will be raised by `Maestro.Aggregate.Root.lookup_module/2`
  if it fails to find the module implied by the prefix and type provided.
  """

  defexception type: ""

  def message(exception) do
    """
    Could not find the matching Command or Event Handler for #{exception.type}.
    """
  end
end

defmodule Maestro.InvalidCommandError do
  @moduledoc """
  The preferred exception for informing the client that their command was
  rejected for any reason.
  """

  defexception message: ""
end
