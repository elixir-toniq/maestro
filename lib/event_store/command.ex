defmodule EventStore.Command do
  @moduledoc false # for now

  defstruct [:type, :aggregate_id, :sequence, :data]
end
