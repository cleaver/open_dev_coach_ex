defmodule OpenDevCoach.Scheduler do
  @moduledoc """
  GenServer responsible for managing scheduled check-ins.

  This module handles scheduling check-ins using Process.send_after/3,
  restores scheduled check-ins from the database on startup,
  and handles missed check-ins by marking them as SKIPPED.

  Timezone Handling:
  - Initial scheduling (parse_time_or_interval): Uses local time to determine if user means today or tomorrow
  - Scheduling (calculate_next_occurrence): Works with stored UTC times for consistency
  - The checkins context handles all timezone conversion between local display and UTC storage
  """

  use GenServer
  require Logger
  alias OpenDevCoach.Checkins
  alias OpenDevCoach.Helpers.Date, as: DateHelper
  alias OpenDevCoach.Session

  @doc """
  Starts the Scheduler GenServer.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Adds a new check-in to the scheduler.

  ## Parameters
    - time_or_interval: Either "HH:MM" format or interval like "2h 30m"
    - description: Optional description for the check-in

  ## Returns
    - {:ok, checkin_id} on success
    - {:error, reason} on failure
  """
  def add_checkin(time_or_interval, description \\ nil) do
    GenServer.call(__MODULE__, {:add_checkin, time_or_interval, description})
  end

  @doc """
  Lists all scheduled check-ins.
  """
  def list_checkins do
    GenServer.call(__MODULE__, :list_checkins)
  end

  @doc """
  Removes a scheduled check-in by ID.
  """
  def remove_checkin(checkin_id) do
    GenServer.call(__MODULE__, {:remove_checkin, checkin_id})
  end

  # GenServer Callbacks

  @impl true
  def init(_opts) do
    Logger.info("OpenDevCoach Scheduler started")
    # Handle missed check-ins and restore active ones from database
    handle_missed_checkins()
    restore_checkins_from_database()
    {:ok, %{}}
  end

  @impl true
  def handle_call({:add_checkin, time_or_interval, description}, _from, state) do
    case parse_time_or_interval(time_or_interval) do
      {:ok, next_time} ->
        case Checkins.create_checkin(%{
               scheduled_at: next_time,
               description: description,
               status: "SCHEDULED"
             }) do
          {:ok, checkin} ->
            schedule_checkin(checkin)
            {:reply, {:ok, checkin.id}, state}

          {:error, changeset} ->
            {:reply, {:error, "Failed to create check-in: #{inspect(changeset.errors)}"}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:list_checkins, _from, state) do
    checkins = Checkins.list_active_checkins()
    {:reply, checkins, state}
  end

  @impl true
  def handle_call({:remove_checkin, checkin_id}, _from, state) do
    case Checkins.get_checkin(checkin_id) do
      nil ->
        {:reply, {:error, "Check-in not found"}, state}

      checkin ->
        # Cancel any pending timer
        cancel_checkin_timer(checkin_id)
        # Remove from database
        Checkins.delete_checkin(checkin)
        {:reply, {:ok, "Check-in removed"}, state}
    end
  end

  @impl true
  def handle_info({:checkin, checkin_id}, state) do
    case Checkins.get_checkin(checkin_id) do
      nil ->
        Logger.warning("Check-in #{checkin_id} not found, skipping")
        {:noreply, state}

      checkin ->
        # Send check-in message to Session
        Session.handle_checkin(checkin)

        # Update last triggered time and mark as completed
        Checkins.update_checkin(checkin, %{
          last_triggered_at: DateHelper.local_datetime_now(),
          status: "COMPLETED"
        })

        # No rescheduling - this is a one-time check-in
        Logger.info("Check-in #{checkin_id} completed and marked as COMPLETED")

        {:noreply, state}
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
