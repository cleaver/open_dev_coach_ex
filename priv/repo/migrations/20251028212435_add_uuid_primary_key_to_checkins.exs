defmodule OpenDevCoach.Repo.Migrations.AddUuidPrimaryKeyToCheckins do
  use Ecto.Migration

  def up do
    # Drop the existing table
    drop table(:checkins)

    # Recreate with UUID primary key
    create table(:checkins, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :scheduled_at, :utc_datetime
      add :status, :string, default: "SCHEDULED"
      add :description, :string
      add :last_triggered_at, :utc_datetime
      add :completed_at, :utc_datetime

      timestamps()
    end

    create index(:checkins, [:scheduled_at])
    create index(:checkins, [:status])
  end

  def down do
    # Drop the UUID table
    drop table(:checkins)

    # Recreate with integer primary key (original)
    create table(:checkins) do
      add :scheduled_at, :utc_datetime
      add :status, :string, default: "SCHEDULED"
      add :description, :string
      add :last_triggered_at, :utc_datetime
      add :completed_at, :utc_datetime

      timestamps()
    end

    create index(:checkins, [:scheduled_at])
    create index(:checkins, [:status])
  end
end
