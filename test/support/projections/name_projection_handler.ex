defmodule Maestro.SampleAggregate.Projections.NameProjectionHandler do
  @moduledoc """
  Attempt to update the named aggregate projection transactionally with the
  corresponding event
  """

  @behaviour Maestro.Aggregate.ProjectionHandler

  alias Maestro.Repo
  alias Maestro.Schemas.NamedAggregate

  def strong?, do: true

  def project(%{
        aggregate_id: agg_id,
        type: "counter_named",
        body: %{"name" => new_name}
      }) do
    {"named_aggregate_projection", __MODULE__, :insert_name, [new_name, agg_id]}
  end

  def project(_), do: nil

  def insert_name(_multi, new_name, aggregate_id) do
    Repo.insert(%NamedAggregate{name: new_name, aggregate_id: aggregate_id})
  end
end
