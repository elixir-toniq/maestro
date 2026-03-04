defmodule Mix.Tasks.Maestro.MigrationHelpers do
  @moduledoc false

  import Mix.Ecto, only: [parse_repo: 1, ensure_repo: 2]
  import Mix.Generator, only: [create_directory: 1, create_file: 2]

  alias Ecto.Migrator

  def resolve_repo(args) do
    [repo | _] = parse_repo(args)
    ensure_repo(repo, args)
    repo
  end

  def migration_path(repo, filename) do
    repo
    |> Migrator.migrations_path()
    |> Path.join("#{timestamp()}_#{filename}.exs")
  end

  def write_migration(path, content) do
    create_directory(Path.dirname(path))
    create_file(path, content)
  end

  def timestamp do
    {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time()
    "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
  end

  defp pad(i) when i < 10, do: <<?0, ?0 + i>>
  defp pad(i), do: to_string(i)
end
