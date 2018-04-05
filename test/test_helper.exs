ExUnit.start()

Maestro.Repo.start_link()
Ecto.Adapters.SQL.Sandbox.mode(Maestro.Repo, :manual)
