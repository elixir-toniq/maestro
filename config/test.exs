use Mix.Config

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :maestro, Maestro.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "maestro_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox
