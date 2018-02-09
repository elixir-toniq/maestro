defmodule Maestro.Command do
  @moduledoc """
  Commands are the primary way clients express a desire to change the system. In
  Maestro, commands are always executed within the context of an aggregate in
  a consistent manner.

  In order to assist the system in promptly processing commands, clients can
  provide a `sequence` number which would give the system a hint that the local
  state is out of date. If that isn't present, the generated events will be
  initially rejected but could be subsequently accepted.
  """

  @type t :: %__MODULE__{
    type: String.t(),
    aggregate_id: HLClock.Timestamp.t(),
    sequence: integer(),
    data: map()
  }

  defstruct [:type, :aggregate_id, sequence: 0, data: %{}]
end
