defmodule OpenDevCoach.CheckinFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `OpenDevCoach.Checkins` context.
  """
  alias OpenDevCoach.Checkins
  alias OpenDevCoach.Helpers.Date, as: DateHelpers

  @doc """
  Generate a checkin. Default is scheduled for 2 hours from now.
  """
  def checkin_fixture(attrs \\ %{}) do
    scheduled_at_date =
      DateHelpers.local_datetime_now()
      |> Timex.shift(hours: 2)

    {:ok, checkin} =
      attrs
      |> Enum.into(%{
        description: "some checkin description",
        status: "SCHEDULED",
        scheduled_at: scheduled_at_date
      })
      |> Checkins.create_checkin()

    checkin
  end

  @doc """
  Generate a completed checkin.
  """
  def completed_checkin_fixture(attrs \\ %{}) do
    now = DateHelpers.local_datetime_now()
    scheduled_at_date = Timex.shift(now, hours: -1)
    triggered_date = Timex.shift(now, hours: -1, seconds: 1)
    completed_at = Timex.shift(now, hours: -1, seconds: 2)

    Enum.into(attrs, %{
      scheduled_at: scheduled_at_date,
      last_triggered_at: triggered_date,
      completed_at: completed_at,
      status: "COMPLETED"
    })
    |> checkin_fixture()
  end

  @doc """
  Generate a skipped checkin.
  """
  def skipped_checkin_fixture(attrs \\ %{}) do
    now = DateHelpers.local_datetime_now()
    scheduled_at_date = Timex.shift(now, hours: -1)

    Enum.into(attrs, %{
      scheduled_at: scheduled_at_date,
      status: "SKIPPED"
    })
    |> checkin_fixture()
  end
end
