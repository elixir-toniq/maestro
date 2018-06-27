defmodule Maestro.Types.Command do
  @moduledoc """
  Commands are the primary way clients express a desire to change the system. In
  Maestro, commands are always executed within the context of an aggregate in a
  consistent manner.
  """

  @type t :: %__MODULE__{
          type: String.t(),
          aggregate_id: HLClock.Timestamp.t(),
          data: map()
        }

  defstruct [:type, :aggregate_id, data: %{}]
end
