defmodule OpenDevCoach.Checkins do
  @moduledoc """
  Context module for managing check-ins in the database.

  This module provides functions for creating, reading, updating, and deleting
  check-ins, as well as querying active check-ins for the scheduler.

  This module serves as the timezone surface - below this layer, everything
  is stored in UTC. Above this layer, times are displayed in the user's local timezone.
  """

  import Ecto.Query
  alias OpenDevCoach.Checkins.Checkin
  alias OpenDevCoach.Helpers.Date, as: DateHelper
  alias OpenDevCoach.Repo

  @doc """
  Creates a new check-in, converting local time to UTC for storage.
  """
  def create_checkin(attrs \\ %{}) do
    # Convert scheduled_at from local time to UTC if present
    attrs = convert_local_to_utc(attrs)

    %Checkin{}
    |> Checkin.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, checkin} -> {:ok, convert_utc_to_local(checkin)}
      error -> error
    end
  end

  @doc """
  Gets a check-in by ID with time converted to local timezone.
  """
  def get_checkin(id) do
    case Repo.get(Checkin, id) do
      nil -> nil
      checkin -> convert_utc_to_local(checkin)
    end
  end

  @doc """
  Lists all check-ins with times converted to local timezone for display.
  """
  def list_checkins do
    Checkin
    |> Repo.all()
    |> Enum.map(&convert_utc_to_local/1)
  end

  @doc """
  Lists only active (scheduled) check-ins with times in local timezone.
  """
  def list_active_checkins do
    Checkin
    |> where([c], c.status == "SCHEDULED")
    |> order_by([c], c.scheduled_at)
    |> Repo.all()
    |> Enum.map(&convert_utc_to_local/1)
  end

  @doc """
  Lists only SCHEDULED check-ins (for scheduler restoration).
  """
  def list_scheduled_checkins do
    Checkin
    |> where([c], c.status == "SCHEDULED")
    |> order_by([c], c.scheduled_at)
    |> Repo.all()
    |> Enum.map(&convert_utc_to_local/1)
  end

  @doc """
  Mark past scheduled checkins as skipped.
  """
  def mark_past_scheduled_checkins_as_skipped do
    now = DateTime.utc_now()

    Checkin
    |> where([c], c.status == "SCHEDULED" and c.scheduled_at < ^now)
    |> Repo.update_all(set: [status: "SKIPPED"])
  end

  @doc """
  Updates a check-in with the given attributes, converting times to UTC if needed.
  """
  def update_checkin(%Checkin{} = checkin, attrs) do
    # Convert any time fields from local to UTC
    attrs = convert_local_to_utc(attrs)

    checkin
    |> Checkin.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, checkin} -> {:ok, convert_utc_to_local(checkin)}
      error -> error
    end
  end

  @doc """
  Deletes a check-in.
  """
  def delete_checkin(%Checkin{} = checkin) do
    Repo.delete(checkin)
  end

  @doc """
  Changes the status of a check-in.
  """
  def change_checkin_status(checkin, status) do
    update_checkin(checkin, %{status: status})
  end

  @doc """
  Marks a check-in as completed.
  """
  def complete_checkin(checkin) do
    update_checkin(checkin, %{
      status: "COMPLETED",
      completed_at: DateTime.utc_now()
    })
  end

  # Private timezone conversion functions

  @doc false
  defp convert_local_to_utc(%{scheduled_at: local_time} = attrs) when not is_nil(local_time) do
    utc_time =
      case local_time do
        %NaiveDateTime{} ->
          # Assume local time, convert to UTC
          local_time
          |> Timex.to_datetime(DateHelper.local_timezone())
          |> Timex.Timezone.convert("Etc/UTC")

        %DateTime{} ->
          # Already a DateTime, ensure it's UTC
          Timex.Timezone.convert(local_time, "Etc/UTC")

        _ ->
          local_time
      end

    %{attrs | scheduled_at: utc_time}
  end

  defp convert_local_to_utc(attrs), do: attrs

  @doc false
  defp convert_utc_to_local(%Checkin{} = checkin) do
    %{
      checkin
      | scheduled_at: convert_datetime_to_local(checkin.scheduled_at),
        last_triggered_at: convert_datetime_to_local(checkin.last_triggered_at),
        completed_at: convert_datetime_to_local(checkin.completed_at)
    }
  end

  @doc false
  defp convert_datetime_to_local(nil), do: nil

  defp convert_datetime_to_local(utc_datetime) do
    utc_datetime
    |> Timex.Timezone.convert(DateHelper.local_timezone())
  end
end
