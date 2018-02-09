defmodule Maestro.Aggregate do
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
  alias Maestro.Command
  alias Maestro.Store
  alias Maestro.Schemas.{Event, Snapshot}

  defstruct [:id, :sequence, :state]

  @type t :: %__MODULE__{
          id: HLClock.Timestamp.t(),
          sequence: integer,
          state: any
        }

  @type agg :: t

  @callback initial_state() :: any
  @callback eval_command(agg, command :: Command.t()) :: [Event.t()]
  @callback apply_event(agg, event :: Event.t()) :: any
  @callback prepare_snapshot(agg) :: map
  @callback use_snapshot(agg, snapshot :: Snapshot.t()) :: any
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

  def start_link(opts) do
    mod = Keyword.get(opts, :module)
    id = Keyword.get(opts, :aggregate_id)
    mod.start_link(id)
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

      defoverridable initial_state: 0,
                     eval_command: 2,
                     apply_event: 2,
                     prepare_snapshot: 1,
                     use_snapshot: 2

      def init(%HLClock.Timestamp{} = id) do
        send(self(), :initialize)
        {:ok, id |> create_aggregate()}
      end

      def handle_call(:get_state, _from, agg), do: {:reply, agg.state, agg}

      def handle_call({:get_state, seq}, _from, agg) do
        {:reply, at_sequence(agg, seq), agg}
      end

      def handle_call(:fetch_state, _from, agg) do
        agg = update_aggregate(agg)
        {:reply, {:ok, agg.state}, agg}
      rescue
        e -> {:reply, {:error, e, System.stacktrace()}, agg}
      end

      def handle_call(:get_snapshot, _from, agg) do
        {:reply, to_snapshot(agg), agg}
      end

      def handle_call({:eval_command, command}, _from, agg) do
        {:reply, :ok, handle_command(agg, command)}
      rescue
        e -> {:reply, {:error, e, System.stacktrace()}, agg}
      end

      def handle_info(:initialize, agg), do: {:noreply, update_aggregate(agg)}

      defp handle_command(agg, com) do
        with agg <- command_update(agg, com),
             evs when is_list(evs) <- eval_command(agg, com),
             %Aggregate{} = agg <- handle_events(agg, com, evs) do
          agg
        end
      end

      defp command_update(%{sequence: a} = agg, %{sequence: c}) when c > a,
        do: update_aggregate(agg)

      defp command_update(agg, _), do: agg

      def handle_events(agg, command, events) do
        case Store.commit_events(events) do
          :ok ->
            apply_events(agg, events)

          {:error, :retry_command} ->
            agg
            |> update_aggregate()
            |> handle_command(command)
        end
      end

      defp create_aggregate(id) do
        %Aggregate{id: id, sequence: 0, state: initial_state()}
      end

      defp to_snapshot(%{id: i, state: s, sequence: n}),
        do: %Snapshot{aggregate_id: i, body: prepare_snapshot(s), sequence: n}

      defp at_sequence(agg, sequence) do
        agg.id
        |> create_aggregate
        |> update_aggregate(sequence)
        |> Map.get(:state)
      end

      defp update_aggregate(agg, max_seq \\ Store.max_sequence()) do
        agg =
          case Store.get_snapshot(
                 agg.id,
                 agg.sequence,
                 max_sequence: max_seq
               ) do
            nil ->
              agg

            snap ->
              %{agg | state: use_snapshot(agg, snap), sequence: snap.sequence}
          end

        events = Store.get_events(agg.id, agg.sequence, max_sequence: max_seq)
        apply_events(agg, events)
      end

      defp max_seq([]), do: nil

      defp max_seq(events) do
        events
        |> Enum.reduce(0, fn event, seq ->
          case event.sequence > seq do
            true -> event.sequence
            false -> seq
          end
        end)
      end

      defp apply_events(agg, []), do: agg

      defp apply_events(agg, events) do
        new_state =
          Enum.reduce(events, agg.state, fn event, state ->
            apply_event(state, event)
          end)

        %{agg | state: new_state, sequence: max_seq(events)}
      end

      def call(agg_id, msg) do
        agg_id
        |> whereis
        |> GenServer.call(msg)
      end

      def whereis(agg_id) do
        Maestro.Aggregate.Supervisor.get_child(agg_id, __MODULE__)
      end

      @doc """
      Commands suppose an `aggregate_id`. This means that aggregates will need
      to be able to generate an ID and an initial state before accepting
      commands.
      """
      def new do
        with {:ok, agg_id} <- HLClock.now() do
          pid =
            agg_id
            |> whereis

          {:ok, pid, agg_id}
        end
      end
    end
  end

  defmacro __before_compile__(_) do
    quote do
      def start_link(agg_id) do
        name = {:via, Registry, {Maestro.Aggregate.Registry, agg_id}}
        GenServer.start_link(__MODULE__, agg_id, name: name)
      end

      def eval_command(_, _), do: {:error, :unrecognized_command}

      # provide a base case for handle_info after the fact, so users can extend
      # handle_info on their own
      def handle_info(_msg, state), do: {:noreply, state}
    end
  end
end
