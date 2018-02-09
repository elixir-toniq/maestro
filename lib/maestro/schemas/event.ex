defmodule Maestro.Schemas.Event do
  @moduledoc """
  Events are the building block of our society. Behave accordingly
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias __MODULE__

  @type sequence :: integer()

  @type aggregate_id :: HLClock.Timestamp.t()

  @type t :: %__MODULE__{
          timestamp: HLClock.Timestamp.t(),
          aggregate_id: aggregate_id(),
          sequence: sequence(),
          body: map()
        }

  @primary_key false
  schema "event_log" do
    field(:timestamp, Ecto.HLClock, primary_key: true)
    field(:aggregate_id, Ecto.HLClock)
    field(:sequence, :integer)
    field(:body, :map)
  end

  def changeset(%Event{} = e) do
    e
    |> change()
    |> validate_required([:timestamp, :aggregate_id, :sequence, :body])
    |> unique_constraint(
      :sequence,
      name: :aggregate_sequence_index,
      message: :dupe_seq_agg
    )
  end
end
