defmodule OpenDevCoach.Repo.Migrations.AddUuidPrimaryKeyToTasks do
  use Ecto.Migration

  def up do
    # Drop the existing table
    drop table(:tasks)

    # Recreate with UUID primary key
    create table(:tasks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :description, :text, null: false
      add :status, :string, default: "PENDING", null: false
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime

      timestamps()
    end

    create index(:tasks, [:status])
  end

  def down do
    # Drop the UUID table
    drop table(:tasks)

    # Recreate with integer primary key (original)
    create table(:tasks) do
      add :description, :text, null: false
      add :status, :string, default: "PENDING", null: false
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime

      timestamps()
    end

    create index(:tasks, [:status])
  end
end
