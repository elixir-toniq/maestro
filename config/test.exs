use Mix.Config

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :event_store, EventStore.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "event_store_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox
