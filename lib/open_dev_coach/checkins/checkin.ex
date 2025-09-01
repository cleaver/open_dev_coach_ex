defmodule OpenDevCoach.Checkins.Checkin do
  @moduledoc """
  Schema for check-ins in the database.

  Check-ins represent scheduled times when the application should
  proactively check in with the user about their progress.
  """

  use Ecto.Schema
  import Ecto.Changeset

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
    |> cast(attrs, [:scheduled_at, :status, :description, :last_triggered_at, :completed_at])
    |> validate_required([:scheduled_at, :status])
    |> validate_inclusion(:status, ["SCHEDULED", "SKIPPED", "COMPLETED", "CANCELLED"])
  end
end
