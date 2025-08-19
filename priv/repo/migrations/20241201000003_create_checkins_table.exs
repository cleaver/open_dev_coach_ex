defmodule OpenDevCoach.Repo.Migrations.CreateCheckinsTable do
  use Ecto.Migration

  def change do
    create table(:checkins) do
      add :scheduled_at, :utc_datetime, null: false
      add :status, :string, default: "PENDING", null: false

      timestamps()
    end

    create index(:checkins, [:scheduled_at])
    create index(:checkins, [:status])
  end
end
