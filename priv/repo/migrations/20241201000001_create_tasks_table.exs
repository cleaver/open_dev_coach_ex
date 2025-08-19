defmodule OpenDevCoach.Repo.Migrations.CreateTasksTable do
  use Ecto.Migration

  def change do
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
