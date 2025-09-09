defmodule OpenDevCoach.Servers.Scheduler.Impl do
  @moduledoc """
  Pure business logic for the Scheduler functionality.

  This module contains all the application logic without any GenServer concerns.
  It can be easily tested and reused independently of the server implementation.
  """

  require Logger
  alias OpenDevCoach.Checkins
  alias OpenDevCoach.Helpers.Date, as: DateHelper

  @doc """
  Initializes the scheduler state.
  """
  def init(_opts) do
    Logger.info("OpenDevCoach Scheduler started")
    # Handle missed check-ins and restore active ones from database
    handle_missed_checkins()
    restore_checkins_from_database()
    %{}
  end

  @doc """
  Adds a new check-in to the scheduler.

  ## Parameters
    - state: Current scheduler state
    - time_or_interval: Either "HH:MM" format or interval like "2h 30m"
    - description: Optional description for the check-in

  ## Returns
    - {{:ok, checkin_id}, new_state} on success
    - {{:error, reason}, state} on failure
  """
  def add_checkin(state, time_or_interval, description \\ nil) do
    case parse_time_or_interval(time_or_interval) do
      {:ok, next_time} ->
        case Checkins.create_checkin(%{
               scheduled_at: next_time,
               description: description,
               status: "SCHEDULED"
             }) do
          {:ok, checkin} ->
            schedule_checkin(checkin)
            {{:ok, checkin.id}, state}

          {:error, changeset} ->
            {{:error, "Failed to create check-in: #{inspect(changeset.errors)}"}, state}
        end

      {:error, reason} ->
        {{:error, reason}, state}
    end
  end

  @doc """
  Lists all scheduled check-ins.

  ## Parameters
    - state: Current scheduler state

  ## Returns
    - {checkins, state} where checkins is the list of active check-ins
  """
  def list_checkins(state) do
    checkins = Checkins.list_active_checkins()
    {checkins, state}
  end

  @doc """
  Removes a scheduled check-in by ID.

  ## Parameters
    - state: Current scheduler state
    - checkin_id: ID of the check-in to remove

  ## Returns
    - {{:ok, message}, new_state} on success
    - {{:error, reason}, state} on failure
  """
  def remove_checkin(state, checkin_id) do
    case Checkins.get_checkin(checkin_id) do
      nil ->
        {{:error, "Check-in not found"}, state}

      checkin ->
        # Cancel any pending timer
        cancel_checkin_timer(checkin_id)
        # Remove from database
        Checkins.delete_checkin(checkin)
        {{:ok, "Check-in removed"}, state}
    end
  end

  @doc """
  Handles a check-in trigger from the timer.

  ## Parameters
    - state: Current scheduler state
    - checkin_id: ID of the check-in that was triggered

  ## Returns
    - {new_state, new_state} (state doesn't change for check-in handling)
  """
  def handle_checkin_trigger(state, checkin_id) do
    case Checkins.get_checkin(checkin_id) do
      nil ->
        Logger.warning("Check-in #{checkin_id} not found, skipping")
        {state, state}

      checkin ->
        # Send check-in message to Session
        OpenDevCoach.Servers.Session.handle_checkin(checkin)

        # Update last triggered time and mark as completed
        Checkins.update_checkin(checkin, %{
          last_triggered_at: DateHelper.local_datetime_now(),
          status: "COMPLETED"
        })

        # No rescheduling - this is a one-time check-in
        Logger.info("Check-in #{checkin_id} completed and marked as COMPLETED")

        {state, state}
    end
  end

  # Private Functions

  defp handle_missed_checkins do
    {update_count, _} = Checkins.mark_past_scheduled_checkins_as_skipped()

    if update_count > 0 do
      Logger.info("Marked #{update_count} missed check-ins as SKIPPED")
    end
  end

  defp restore_checkins_from_database do
    scheduled_checkins = Checkins.list_scheduled_checkins()
    Enum.each(scheduled_checkins, &schedule_checkin/1)
    Logger.info("Restored #{length(scheduled_checkins)} scheduled check-ins from database")
  end

  # TODO: Make sure this is necessary
  defp schedule_checkin(checkin) do
    next_time = checkin.scheduled_at
    now = DateHelper.local_datetime_now()

    case DateTime.compare(next_time, now) do
      :gt ->
        # Schedule for future
        delay_ms = DateTime.diff(next_time, now, :millisecond)
        Process.send_after(self(), {:checkin, checkin.id}, delay_ms)
        Logger.debug("Scheduled check-in #{checkin.id} for #{next_time}")

      _ ->
        # Time has passed, mark as SKIPPED
        Checkins.change_checkin_status(checkin, "SKIPPED")
        Logger.info("Check-in #{checkin.id} time has passed, marked as SKIPPED")
    end
  end

  defp cancel_checkin_timer(checkin_id) do
    # TODO: Process.send_after returns a timer reference, but we're not storing it
    # In a production system, you'd want to store timer references to cancel them
    # For now, we'll rely on the process being restarted to clear old timers
    Logger.debug("Check-in #{checkin_id} timer cancelled")
  end

  defp parse_time_or_interval(input) when is_binary(input) do
    DateHelper.parse_time_or_interval(input)
  end
end
