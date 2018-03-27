defmodule Maestro.Aggregate.Root do
  @moduledoc """
  Traditional domain entities are referred to as aggregates in the literature.
  At the outermost edge of a bounded context, you find an aggregate root. The
  goal of this library is to greatly simplify the process of implementing an
  event sourced application by owning the flow of non-domain data (i.e.
  commands, events, and snapshots) to allow you to focus on the business logic
  of evaluating your commands and applying the subsequent events to your domain
  objects.

  The most crucial piece to this is the aggregate root. `Command` defines a
  `behaviour` with the goal of isolating a single command handler's `eval`.
  Similarly, there is an `Event` behaviour which defines how to `apply` that
  event to the aggregate. With these key components modeled explicitly, the
  `Maestro.Aggregate.Root` focuses on the dataflow and ensuring that queries to
  aggregate state flow properly.

  The aggregate root dispatches to the particular command handlers and event
  handlers by means of an opinionated dynamic dispatch. To ensure that these
  things are handled in a consistent manner, the aggregate root is modeled as a
  `GenServer` and provides the requisite lifecycle hooks.

  `use Maestro.Aggregate.Root` takes the following options:
  * `:command_prefix` - module prefix for finding commands
  * `:event_prefix` - module prefix for finding events
  """

  alias Maestro.{InvalidHandlerError, Store}

  alias Maestro.Aggregate.Supervisor
  alias Maestro.Types.Snapshot

  defstruct [:id, :sequence, :state, :module, :command_prefix, :event_prefix]

  @type id :: HLClock.Timestamp.t()

  @type stack :: Exception.stacktrace()

  @type sequence :: non_neg_integer()

  @type command :: Maestro.Types.Command.t()

  @type t :: %__MODULE__{
          id: id(),
          sequence: sequence(),
          state: any(),
          module: module(),
          command_prefix: module(),
          event_prefix: module()
        }

  defmacro __using__(opts) do
    quote location: :keep do
      use GenServer

      alias HLClock.Timestamp
      alias unquote(__MODULE__)

      @behaviour unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
      @command_prefix Keyword.get(unquote(opts), :command_prefix, __MODULE__)
      @event_prefix Keyword.get(unquote(opts), :event_prefix, __MODULE__)

      # Public API

      def get_state(agg_id), do: call(agg_id, :get_current)

      def get_latest(agg_id), do: call(agg_id, :get_latest)

      def hydrate(agg_id, seq), do: call(agg_id, {:hydrate, seq})

      def evaluate(agg_id, command), do: call(agg_id, {:eval_command, command})

      def snapshot(agg_id) do
        with {:ok, snap} <- call(agg_id, :get_snapshot) do
          Root.persist_snapshot(snap)
        end
      rescue
        err -> {:error, err, System.stacktrace()}
      end

      def call(agg_id, msg) do
        agg_id
        |> Root.whereis(__MODULE__)
        |> GenServer.call(msg)
      end

      def new do
        with {:ok, agg_id} <- HLClock.now() do
          pid =
            agg_id
            |> Root.whereis(__MODULE__)

          {:ok, pid, agg_id}
        end
      end

      # Callback Functions

      def initial_state, do: %{}

      def prepare_snapshot(state), do: state

      def use_snapshot(_, snapshot), do: snapshot.body

      defoverridable initial_state: 0, prepare_snapshot: 1, use_snapshot: 2

      # GenServer Functions

      def init(%Timestamp{} = id) do
        send(self(), :init)

        agg =
          Root.create_aggregate(
            id,
            __MODULE__,
            @command_prefix,
            @event_prefix
          )

        {:ok, agg}
      end

      def handle_call(:get_latest, _from, agg) do
        agg = Root.update_aggregate(agg)
        {:reply, {:ok, agg.state}, agg}
      rescue
        err ->
          {:reply, {:error, err, System.stacktrace()}, agg}
      end

      def handle_call(:get_current, _from, agg) do
        {:reply, {:ok, agg.state}, agg}
      end

      def handle_call({:hydrate, seq}, _from, agg) do
        {:reply, {:ok, Root.hydrate(agg, seq)}, agg}
      rescue
        err -> {:reply, {:error, err, System.stacktrace()}, agg}
      end

      def handle_call(:get_snapshot, _from, agg) do
        body = prepare_snapshot(agg.state)
        {:reply, {:ok, Root.to_snapshot(agg, body)}, agg}
      rescue
        err -> {:reply, {:error, err, System.stacktrace()}, agg}
      end

      def handle_call({:eval_command, command}, _from, agg) do
        {:reply, :ok, Root.eval_command(agg, command)}
      rescue
        err -> {:reply, {:error, err, System.stacktrace()}, agg}
      end

      def handle_info(:init, agg), do: {:noreply, Root.update_aggregate(agg)}
    end
  end

  defmacro __before_compile__(_) do
    quote do
      def start_link(%HLClock.Timestamp{} = agg_id) do
        name = {:via, Registry, {Maestro.Aggregate.Registry, agg_id}}
        GenServer.start_link(__MODULE__, agg_id, name: name)
      end

      def handle_info(_msg, agg), do: {:noreply, agg}
    end
  end

  @doc """
  Create a new aggregate along with the provided `initial_state` function. This
  function should only fail if there was a problem generating an HLC timestamp.
  """
  @callback new() :: {:ok, pid(), id()} | {:error, any()}

  @doc """
  When an aggregate root is created, this callback is invoked to generate the
  state
  """
  @callback initial_state() :: any()

  @doc """
  Snapshots are stored in a single-row-per-aggregate manner and are used to make
  it easier/faster to hydrate the aggregate root. This function should return
  the map which will be JSON encoded when moving to a durable store.
  """
  @callback prepare_snapshot(root :: t()) :: map()

  @doc """
  Moving from the snapshotted representation to the aggregate root's structure
  can be a complicated process that requires custom hooks. Otherwise, a default
  implementation is provided that simply lifts the map out of the snapshot and
  uses it as the state of the aggregate.
  """
  @callback use_snapshot(root :: t(), snapshot :: Snapshot.t()) :: any()

  @doc """
  Provided by default, it is a stale read of the aggregate's state. If you want
  to ensure the state is as up-to-date as possible, see `get_latest`.
  """
  @callback get_state(id()) :: {:ok, any()} | {:error, any(), stack()}

  @doc """
  Forces the aggregate to retrieve any events. Since Maestro operates in a
  node-local first manner, it's entirely possible some other node has processed
  commands/events.
  """
  @callback get_latest(id()) :: {:ok, any()} | {:error, any(), stack()}

  @doc """
  Recover a past version of the aggregate's state by specifying a maximum
  sequence number. The aggregate's snapshot and any/all events will be used to
  get the state back to that point.
  """
  @callback hydrate(id(), sequence()) :: {:ok, any()} | {:error, any(), stack()}

  @doc """
  Evaluate the command within the aggregate's context.
  """
  @callback evaluate(id(), command()) :: :ok | {:error, any(), stack()}

  @doc """
  Using the aggregate root's `prepare_snapshot` function, generate and store a
  snapshot. Useful if there are a lot of events, big events, or just a healthy
  amount of aggregate state to compose.
  """
  @callback snapshot(id()) :: :ok | {:error, any(), stack()}

  @doc """
  If you extend the aggregate to provide other functionality, `call` is
  available to assist in pushing that functionality into the aggregate's
  context.
  """
  @callback call(id(), msg :: any()) :: any()

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
    mod = Keyword.fetch!(opts, :module)
    id = Keyword.fetch!(opts, :aggregate_id)
    mod.start_link(id)
  end

  @doc false
  def create_aggregate(agg_id, mod, command_prefix, event_prefix) do
    %__MODULE__{
      id: agg_id,
      sequence: 0,
      state: mod.initial_state(),
      module: mod,
      command_prefix: command_prefix,
      event_prefix: event_prefix
    }
  end

  @doc false
  def update_aggregate(agg, max_seq \\ Store.max_sequence()) do
    # from latest snapshot
    agg =
      case Store.get_snapshot(
             agg.id,
             agg.sequence,
             max_sequence: max_seq
           ) do
        nil ->
          agg

        %Snapshot{} = snap ->
          %{
            agg
            | state: agg.module.use_snapshot(agg, snap),
              sequence: snap.sequence
          }
      end

    # plus trailing events
    events = Store.get_events(agg.id, agg.sequence, max_sequence: max_seq)
    apply_events(agg, events)
  end

  @doc false
  def hydrate(agg, target_seq) do
    agg.id
    |> create_aggregate(agg.module, agg.command_prefix, agg.event_prefix)
    |> update_aggregate(target_seq)
    |> Map.get(:state)
  end

  @doc false
  def eval_command(agg, command) do
    with seq <- Map.get(command, :sequence, 0),
         agg <- update_aggregate(agg, seq),
         module <- lookup_module(agg.command_prefix, command.type),
         events <- module.eval(agg, command) do
      persist_events(agg, command, events)
    end
  end

  @doc false
  def persist_snapshot(snapshot) do
    Store.commit_snapshot(snapshot)
  end

  defp persist_events(agg, command, events) do
    case Store.commit_events(events) do
      :ok ->
        apply_events(agg, events)

      {:error, :retry_command} ->
        agg
        |> update_aggregate()
        |> eval_command(command)
    end
  end

  @doc false
  def apply_events(agg, []), do: agg

  @doc false
  def apply_events(agg, events) do
    state =
      Enum.reduce(events, agg.state, fn event, state ->
        module = lookup_module(agg.event_prefix, event.type)
        module.apply(state, event)
      end)

    %{agg | state: state, sequence: max_seq(events)}
  end

  @doc false
  def to_snapshot(agg, body) do
    %Snapshot{
      aggregate_id: agg.id,
      sequence: agg.sequence,
      body: body
    }
  end

  @doc false
  def lookup_module(prefix, type) do
    name =
      type
      |> String.split(".")
      |> Enum.map_join(".", &Macro.camelize/1)

    case Code.ensure_loaded(Module.safe_concat(prefix, name)) do
      {:module, module} -> module
    end
  rescue
    _ -> reraise(InvalidHandlerError, [type: type], System.stacktrace())
  end

  @doc false
  def whereis(agg_id, mod), do: Supervisor.get_child(agg_id, mod)

  defp max_seq(events), do: events |> List.last() |> Map.get(:sequence)
end
