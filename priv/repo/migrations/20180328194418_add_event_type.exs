defmodule Maestro.Repo.Migrations.AddEventType do
  use Ecto.Migration

  def change do
    alter table(:event_log) do
      add :type, :string, size: 256, null: false
    end
  end
end
