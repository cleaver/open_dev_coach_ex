defmodule OpenDevCoach.Tasks.Task do
  @moduledoc """
  Schema for tasks in the OpenDevCoach application.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t() :: %__MODULE__{
          id: binary(),
          description: String.t(),
          status: String.t(),
          started_at: DateTime.t(),
          completed_at: DateTime.t()
        }

  @required_fields ~w(id description status)a
  @optional_fields ~w(started_at completed_at inserted_at updated_at)a
  @all_fields @required_fields ++ @optional_fields

  @doc "Task status values."
  def task_status_values, do: ~w(PENDING IN-PROGRESS ON-HOLD COMPLETED)

  @primary_key {:id, :binary_id, autogenerate: true}
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
    |> cast(attrs, @all_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:status, task_status_values())
    |> validate_length(:description, min: 1, max: 1000)
  end
end
