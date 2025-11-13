defmodule OpenDevCoach.Repo.Migrations.AddUuidPrimaryKeyToAgentHistory do
  use Ecto.Migration

  def up do
    # Drop the existing table
    drop table(:agent_history)

    # Recreate with UUID primary key
    create table(:agent_history, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :role, :string, null: false
      add :content, :text, null: false
      add :timestamp, :utc_datetime, null: false

      timestamps()
    end

    create index(:agent_history, [:timestamp])
    create index(:agent_history, [:role])
  end

  def down do
    # Drop the UUID table
    drop table(:agent_history)

    # Recreate with integer primary key (original)
    create table(:agent_history) do
      add :role, :string, null: false
      add :content, :text, null: false
      add :timestamp, :utc_datetime, null: false

      timestamps()
    end

    create index(:agent_history, [:timestamp])
    create index(:agent_history, [:role])
  end
end
