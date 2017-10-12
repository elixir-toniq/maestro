defmodule EventStore.Command do
  @moduledoc false # for now

  defstruct [:type, :entity_id, :sequence, :data]
end
