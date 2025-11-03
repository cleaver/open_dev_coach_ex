defmodule OpenDevCoach.Checkins.Checkin do
  @moduledoc """
  Schema for check-ins in the database.

  Check-ins represent scheduled times when the application should
  proactively check in with the user about their progress.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @required_fields [:id, :scheduled_at, :status]
  @optional_fields [:description, :last_triggered_at, :completed_at]
  @all_fields @required_fields ++ @optional_fields

  @doc "Checkin status values"
  def checkin_status_values, do: ["SCHEDULED", "SKIPPED", "COMPLETED", "CANCELLED"]

  @type t() :: %__MODULE__{
          id: binary(),
          scheduled_at: DateTime.t(),
          status: String.t(),
          description: String.t(),
          last_triggered_at: DateTime.t(),
          completed_at: DateTime.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "checkins" do
    field(:scheduled_at, :utc_datetime)
    field(:status, :string, default: "SCHEDULED")
    field(:description, :string)
    field(:last_triggered_at, :utc_datetime)
    field(:completed_at, :utc_datetime)

    timestamps()
  end

  def changeset(checkin, attrs) do
    checkin
    |> cast(attrs, @all_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:status, checkin_status_values())
  end
end
