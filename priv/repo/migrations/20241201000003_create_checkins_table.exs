defmodule OpenDevCoach.Repo.Migrations.CreateCheckinsTable do
  use Ecto.Migration

  def change do
    create table(:checkins) do
      add :scheduled_at, :utc_datetime, null: false
      add :status, :string, default: "SCHEDULED", null: false
      add :description, :string
      add :last_triggered_at, :utc_datetime
      add :completed_at, :utc_datetime

      timestamps()
    end

    create index(:checkins, [:scheduled_at])
    create index(:checkins, [:status])
  end
end
