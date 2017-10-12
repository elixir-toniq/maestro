defmodule EventStore.Aggregate do
  @moduledoc """
  Traditional domain entities are referred to as aggregates in the literature.
  The goal of this library is to greatly simplify the process of implementing a
  event sourcing application by owning the flow of non-domain data (i.e.
  commands, events, and snapshots) to allow you to focus on the business logic
  of evaluating commands and applying events to your domain objects.

  The most crucial piece to this is the aggregate. It defines a `behaviour`
  wherein the developer must implement the callbacks for `eval_command` and
  `apply_event`. This allows the library to work through the lifecycle of a
  command and its events in a controlled, consistent manner.

  The aggregate behaviour provides the following utilities for managing state:
    * ID and sequence tracking (to reduce duplication of effort)
    * all necessary GenServer hooks (i.e. `handle_call`, `start_link`,`init`)
    * updating state via snapshots and events
  """

  alias EventStore.Command
  alias EventStore.Store
  alias EventStore.Schemas.{Event, Snapshot}

  @callback eval_command(state :: any, command :: Command.t) :: [Event.t]
  @callback apply_event(state :: any, event :: Event.t) :: any
  @callback use_snapshot(curr :: any, snapshot :: Snapshot.t) :: any

  defmacro __using__(_) do
    quote location: :keep do
      use GenServer

      @behaviour unquote(__MODULE__)
      @before_compile unquote(__MODULE__)

      def init(%HLClock.Timestamp{} = id) do
        {:ok, %{id: id, sequence: 0, state: nil}}
      end

      def handle_call(:get_state, _from, state), do: {:reply, state, state}

      def handle_call(:snapshot, _from, agg), do: {:ok, to_snapshot(agg), agg}

      def handle_call(:update_state, _from, agg),
        do: {:reply, :ok, update_aggregate(agg)}

      def handle_call({:eval_command, command}, _from, agg) do
        # command implies knowledge of events we haven't seen yet, update before
        # processing
        agg = case command.sequence > agg.sequence do
                true -> update_aggregate(agg)
                false -> agg
              end

        {:reply, eval_command(agg.state, command), agg}
      end

      def handle_call({:apply_events, []}, _from, state),
        do: {:reply, :ok, state}
      def handle_call({:apply_events, events}, _from, state) do
        {:reply, :ok, apply_events(state, events)}
      end

      def eval_command(_, _), do: []

      def apply_event(prev, _), do: prev

      def use_snapshot(_, snapshot), do: snapshot.body

      defoverridable unquote(__MODULE__)

      def to_snapshot(%{id: i, state: s, sequence: n}),
        do: %Snapshot{aggregate_id: i, body: s, sequence: n}

      def update_aggregate(agg) do
        {state, seq} = case Store.get_snapshot(agg.id, agg.sequence) do
                         nil -> {agg.state, agg.sequence}
                         snap -> {use_snapshot(agg.state, snap), snap.sequence}
                       end
        events = Store.get_events(agg.id, seq)
        %{agg | state: apply_events(state, events),
          sequence: new_seq(events) || seq}
      end

      defp new_seq(events), do: events |> max_seq()

      defp max_seq([]), do: nil
      defp max_seq(events) do
        events
        |> Enum.reduce(0, fn (event, seq) ->
          case event.sequence > seq do
            true -> event.sequence
            false -> seq
          end
        end)
      end

      def apply_events(state, events) do
        Enum.reduce(events, state, &apply_event/2)
      end
    end
  end

  defmacro __before_compile__(_) do
    quote do
      def start_link(registry, agg_id) do
        GenServer.start_link(__MODULE__, agg_id, name: {registry, agg_id})
      end
    end
  end
end
