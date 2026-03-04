defmodule Mix.Tasks.Maestro.Create.PartitionedEventStoreMigration do
  @moduledoc """
  Generate a migration that creates hash-partitioned `event_log` and
  (unpartitioned) `snapshots` tables with HLC constraints.

  Hash partitioning on `aggregate_id` distributes data and index load across
  N partitions, improving write throughput and query performance for
  aggregate-scoped reads.

  > **Note on the Event schema:** `Maestro.Types.Event` marks only `timestamp`
  > as `primary_key: true`. The partitioned table PK must be `(aggregate_id, timestamp)`
  > because PostgreSQL requires the partition key in all unique indexes and PKs. A
  > consequence of this, then, is that there is no global uniqueness on timestamp;
  > as a best effort, we guarantee uniqueness per-partition.

  ## Examples

      mix maestro.create.partitioned_event_store_migration --repo MyApp.Repo -p 7
      mix maestro.create.partitioned_event_store_migration --repo MyApp.Repo --partitions 17 -n custom_name
  """

  use Mix.Task

  import Mix.Generator, only: [embed_template: 2]

  alias Mix.Tasks.Maestro.MigrationHelpers

  @doc false
  def run(args) do
    repo = MigrationHelpers.resolve_repo(args)
    {opts, _, _} = parse_options(args)

    partition_count = Keyword.fetch!(opts, :partitions)

    migration_name =
      Keyword.get(opts, :name, "partitioned_event_log_and_snapshots")

    file = MigrationHelpers.migration_path(repo, migration_name)

    assigns = [
      mod: Module.concat([repo, Migrations, PartitionedEventLogAndSnapshots]),
      partition_count: partition_count
    ]

    MigrationHelpers.write_migration(file, migration_template(assigns))
  end

  defp parse_options(args) do
    {parsed, rest, invalid} =
      OptionParser.parse(
        args,
        aliases: [p: :partitions, n: :name],
        strict: [partitions: :integer, name: :string]
      )

    unless Keyword.has_key?(parsed, :partitions) do
      Mix.raise("--partitions is required (integer > 1)")
    end

    p = Keyword.fetch!(parsed, :partitions)

    unless is_integer(p) and p > 1 do
      Mix.raise("--partitions must be an integer > 1, got: #{inspect(p)}")
    end

    {parsed, rest, invalid}
  end

  embed_template(:migration, ~S'''
  defmodule <%= inspect @mod %> do
    use Ecto.Migration

    @partition_count <%= @partition_count %>

    def up do
      execute """
      CREATE TABLE event_log (
        timestamp bytea NOT NULL,
        aggregate_id bytea NOT NULL,
        sequence integer NOT NULL,
        type varchar(256) NOT NULL,
        body jsonb NOT NULL,
        PRIMARY KEY (aggregate_id, timestamp)
      ) PARTITION BY HASH (aggregate_id)
      """

      for i <- 0..(@partition_count - 1) do
        execute """
        CREATE TABLE event_log_#{i}
          PARTITION OF event_log
          FOR VALUES WITH (MODULUS #{@partition_count}, REMAINDER #{i})
        """

        execute """
        CREATE UNIQUE INDEX event_log_#{i}_timestamp_idx ON event_log_#{i} (timestamp)
        """
      end

      EctoHLClock.Migration.create_hlc_constraint(:event_log, :timestamp)
      EctoHLClock.Migration.create_hlc_constraint(:event_log, :aggregate_id)

      create constraint(:event_log, :sequence, check: "sequence > 0")
      create unique_index(:event_log, [:aggregate_id, :sequence],
        name: "aggregate_sequence_index")

      create table(:snapshots, primary_key: false) do
        add :aggregate_id, :binary, null: false, primary_key: true
        add :sequence, :integer, null: false
        add :body, :map, null: false
      end

      EctoHLClock.Migration.create_hlc_constraint(:snapshots, :aggregate_id)
    end

    def down do
      drop table(:snapshots)
      drop table(:event_log)
    end
  end
  ''')
end
