defmodule OpenDevCoach.Repo.Migrations.CreateAgentHistoryTable do
  use Ecto.Migration

  def change do
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
