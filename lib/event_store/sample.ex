defmodule EventStore.Sample do
  @moduledoc false
  import EventStore.Command, only: [command: 2]

  command("sample", EventStore.Brosephus)
  command("brah", EventStore.Brosephus)
end

defmodule EventStore.Brosephus do
  @moduledoc false
  use EventStore.Command

  def handle_command(%{command: "sample"} = _command) do
    []
  end
  def handle_command(%{command: "brah"} = _command) do
    :noice
  end
end

defmodule EventStore.Lazy do
  @moduledoc false
  use EventStore.Command
end
