defmodule Maestro.Schemas.Snapshot do
  @moduledoc """
  aggregate roots can commit state that has been computed from the application
  of events. this is useful if events are expensive to apply or if there are a
  sufficiently large number of events that replaying from sequence=1 would be
  impractical.

  With events, `:body` is the necessary information to apply the event. In the
  case of snapshots, the body is the actual computed state of the entity.
  """

  use Ecto.Schema

  @type sequence :: integer()

  @type aggregate_id :: HLClock.Timestamp.t()

  @type t :: %__MODULE__{
          aggregate_id: aggregate_id(),
          sequence: sequence(),
          body: map()
        }

  @primary_key false
  schema "snapshots" do
    field(:aggregate_id, Ecto.HLClock, primary_key: true)
    field(:sequence, :integer)
    field(:body, :map)
  end
end
