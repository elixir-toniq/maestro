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

  alias __MODULE__
  alias EventStore.Command
  alias EventStore.Store
  alias EventStore.Schemas.{Event, Snapshot}

  defstruct [:id, :sequence, :state]
  @type t :: %__MODULE__{
    id: HLClock.Timestamp.t,
    sequence: integer,
    state: any
  }

  @callback initial_state() :: any
  @callback eval_command(agg :: Aggregate.t, command :: Command.t) :: [Event.t]
  @callback apply_event(agg :: Aggregate.t, event :: Event.t) :: any
  @callback prepare_snapshot(agg :: Aggregate.t) :: map
  @callback use_snapshot(agg :: Aggregate.t, snapshot :: Snapshot.t) :: any
  @optional_callbacks initial_state: 0, prepare_snapshot: 1, use_snapshot: 2

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :temporary,
      shutdown: 500
    }
  end

  def start_link(agg_id, module_name) do
    module_name.start_link(agg_id)
  end

  defmacro __using__(_) do
    quote location: :keep do
      use GenServer

      import unquote(__MODULE__)

      @behaviour unquote(__MODULE__)
      @before_compile unquote(__MODULE__)

      def initial_state, do: %{}

      def eval_command(_, _), do: []

      def apply_event(prev, _), do: prev

      def prepare_snapshot(s), do: s

      def use_snapshot(_, snapshot), do: snapshot.body

      defoverridable [
        initial_state: 0,
        eval_command: 2,
        apply_event: 2,
        prepare_snapshot: 1,
        use_snapshot: 2
      ]

      def init(%HLClock.Timestamp{} = id) do
        send(self(), :initialize)
        {:ok, id |> create_aggregate()}
      end

      def handle_call(:get_state, _from, agg), do: {:reply, agg.state, agg}
      def handle_call({:get_state, seq}, _from, agg) do
        {:reply, at_sequence(agg, seq), agg}
      end
      def handle_call(:get_snapshot, _from, agg) do
        {:reply, to_snapshot(agg), agg}
      end
      def handle_call({:eval_command, command}, _from, agg) do
        {:reply, :ok, handle_command(agg, command)}
      end

      def handle_info(:initialize, agg), do: {:noreply, update_aggregate(agg)}
      def handle_info(_msg, state), do: {:noreply, state}

      def handle_command(agg, com) do
        with agg                   <- command_update(agg, com),
             evs when is_list(evs) <- eval_command(agg, com),
               %Aggregate{} = agg  <- handle_events(agg, com, evs) do
          agg
        end
      end

      defp command_update(%{sequence: a} = agg, %{sequence: c}) when c > a,
        do: update_aggregate(agg)
      defp command_update(agg, _), do: agg

      def handle_events(agg, command, events) do
        case Store.commit_events!(events) do
          :ok -> apply_events(agg, events)
          {:error, :retry_command} ->
            agg
            |> update_aggregate()
            |> handle_command(command)
        end
      end

      def create_aggregate(id) do
        %Aggregate{id: id, sequence: 0, state: initial_state()}
      end

      def to_snapshot(%{id: i, state: s, sequence: n}),
        do: %Snapshot{aggregate_id: i, body: prepare_snapshot(s), sequence: n}

      def at_sequence(agg, sequence) do
        agg.id
        |> create_aggregate
        |> update_aggregate(sequence)
      end

      def update_aggregate(agg, max_seq \\ nil) do
        agg = case Store.get_snapshot(
                    agg.id,
                    agg.sequence,
                    max_sequence: max_seq
                  ) do
                nil -> agg
                snap -> %{agg | state: use_snapshot(agg, snap),
                         sequence: snap.sequence}
              end
        events = Store.get_events(agg.id, agg.sequence)
        apply_events(agg, events)
      end

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

      def apply_events(agg, []), do: agg
      def apply_events(agg, events) do
        new_state = Enum.reduce(
          events,
          agg.state,
          fn (event, state) -> apply_event(state, event) end
        )

        %{agg | state: new_state, sequence: max_seq(events)}
      end

      def call(agg_id, msg) do
        agg_id
        |> whereis
        |> GenServer.call(msg)
      end

      def whereis(agg_id) do
        EventStore.Aggregate.Supervisor.get_child(agg_id, __MODULE__)
      end
    end
  end

  defmacro __before_compile__(_) do
    quote do
      def start_link(agg_id) do
        name = {:via, Registry, {EventStore.Aggregate.Registry, agg_id}}
        GenServer.start_link(__MODULE__, agg_id, name: name)
      end
      def eval_command(_, _), do: {:error, :unrecognized_command}
    end
  end

  def default_registry_fn(agg_id), do: {:global, agg_id}
end
