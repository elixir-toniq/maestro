# Maestro

Maestro is an event sourcing _library_. It is inspired by CQRS and re-uses
terminology where appropriate. The divergence from being a CQRS framework is
intentional as Maestro focuses on processing commands in a consistent manner and
replaying events in a consistent order.

Currently, the only storage adapter suited to a multi-node environment is the
`Maestro.Store.Postgres` adapter. The `Maestro.Store.InMemory` adapter exists
for testing purposes only.

## Status
[![Hex](http://img.shields.io/hexpm/v/maestro.svg?style=flat)](https://hex.pm/packages/maestro)
[![Build Status](https://travis-ci.org/toniqsystems/maestro.svg?branch=master)](https://travis-ci.org/toniqsystems/maestro)
[![Coverage](https://coveralls.io/repos/github/toniqsystems/maestro/badge.svg)](https://coveralls.io/github/toniqsystems/maestro)

Documentation is available [here](https://hexdocs.pm/maestro/).

## Installation

```elixir
def deps do
  [{:maestro, "~> 0.2"}]
end
```

## Database Configuration

Maestro is intended to be used alongside an existing database/ecto repo.

```elixir
config :maestro,
  storage_adapter: Maestro.Store.Postgres,
  repo: MyApp.Repo
```

To generate the migrations for the snapshot and event logs, do:

```bash
mix maestro.create.event_store_migration
```

## Example

There are three behaviours that make the command/event lifecycle flow:
`Maestro.Aggregate.CommandHandler`, `Maestro.Aggregate.EventHandler`, and
`Maestro.Aggregate.ProjectionHandler`. Modules implementing the command and
event handler behaviours are looked up via a configurable `:command_prefix` and
`:event_prefix` respectively. Projections are reserved for maintaining other
models/representations within the event's transaction.

```elixir
defmodule MyApp.Aggregate do
  use Maestro.Aggregate.Root,
    command_prefix: MyApp.Aggregate.Commands,
    event_prefix: MyApp.Aggregate.Events

  def initial_state, do: %{"value" => 0}

  def prepare_snapshot(state), do: state

  def use_snapshot(_curr, %Maestro.Types.Snapshot{body: state}), do: state
end

defmodule MyApp.Aggregate.Commands.IncrementCounter do

  @behaviour Maestro.Aggregate.CommandHandler

  alias Maestro.Types.Event

  def eval(aggregate, _command) do
    [
      %Event{
        aggregate_id: aggregate.id,
        type: "counter_incremented",
        body: %{}
      }
    ]
  end
end

defmodule MyApp.Aggregate.Events.CounterIncremented do

  @behaviour Maestro.Aggregate.EventHandler

  def apply(state, _event), do: Map.update!(state, "value", &(&1 + 1))
end
```

```elixir
iex(1)> {:ok, id} = MyApp.Aggregate.new()
iex(2)> :ok = MyApp.Aggregate.evaluate(%Maestro.Types.Command{aggregate_id: id, type: "increment_counter", data: %{}})
iex(3)> {:ok, %{"value" => 1}} = MyApp.Aggregate.get(id)
```
