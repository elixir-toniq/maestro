# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :event_store,
  ecto_repos: [EventStore.Repo],
  generators: [binary_id: true]

# Configures the endpoint
config :event_store, EventStoreWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "ulWS7RjSlgM8QpY1ROP50XLxAp1hvoRodcUKAnxdVupH22M44czcDtSATyuwxm3+",
  render_errors: [view: EventStoreWeb.ErrorView, accepts: ~w(json)],
  pubsub: [name: EventStore.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
