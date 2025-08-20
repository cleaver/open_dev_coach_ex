defmodule OpenDevCoach.Tasks.Task do
  @moduledoc """
  Schema for tasks in the OpenDevCoach application.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "tasks" do
    field(:description, :string)
    field(:status, :string, default: "PENDING")
    field(:started_at, :utc_datetime)
    field(:completed_at, :utc_datetime)

    timestamps()
  end

  @doc false
  def changeset(task, attrs) do
    task
    |> cast(attrs, [:description, :status, :started_at, :completed_at])
    |> validate_required([:description])
    |> validate_inclusion(:status, ["PENDING", "IN-PROGRESS", "ON-HOLD", "COMPLETED"])
    |> validate_length(:description, min: 1, max: 1000)
  end
end
