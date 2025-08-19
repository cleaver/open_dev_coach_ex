defmodule OpenDevCoach.Repo.Migrations.CreateConfigurationsTable do
  use Ecto.Migration

  def change do
    create table(:configurations) do
      add :key, :string, null: false
      add :value, :text, null: false

      timestamps()
    end

    create unique_index(:configurations, [:key])
  end
end
