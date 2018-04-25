defmodule Maestro.SampleAggregate.Projections.NameProjectionHandler do
  @moduledoc """
  Attempt to update the named aggregate projection transactionally with the
  corresponding event
  """

  @behaviour Maestro.Aggregate.ProjectionHandler

  alias Maestro.Repo
  alias Maestro.Schemas.NamedAggregate

  def project(%{
        aggregate_id: agg_id,
        type: "counter_named",
        body: %{"name" => new_name}
      }) do
    Repo.insert(%NamedAggregate{name: new_name, aggregate_id: agg_id})
  end

  def project(_), do: nil
end
