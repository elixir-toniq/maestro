defmodule Maestro.SampleAggregate.Projections.TagProjectionHandler do
  @moduledoc """
  Rejects the reserved tag by returning an error tuple, demonstrating that a
  projection can veto a commit without raising.
  """

  @behaviour Maestro.Aggregate.ProjectionHandler

  def project(_repo, %{type: "counter_tagged", body: %{tag: "reserved"}}) do
    {:error, "reserved tag is reserved"}
  end

  def project(_, _), do: nil
end
