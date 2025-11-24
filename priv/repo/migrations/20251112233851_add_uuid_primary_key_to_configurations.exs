defmodule OpenDevCoach.Repo.Migrations.AddUuidPrimaryKeyToConfigurations do
  use Ecto.Migration

  def up do
    # Drop the existing table
    drop table(:configurations)

    # Recreate with UUID primary key
    create table(:configurations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :key, :string, null: false
      add :value, :text, null: false

      timestamps()
    end

    create unique_index(:configurations, [:key])
  end

  def down do
    # Drop the UUID table
    drop table(:configurations)

    # Recreate with integer primary key (original)
    create table(:configurations) do
      add :key, :string, null: false
      add :value, :text, null: false

      timestamps()
    end

    create unique_index(:configurations, [:key])
  end
end
