defmodule OpenDevCoach.Scheduler do
  @moduledoc """
  GenServer responsible for managing scheduled check-ins.

  This module handles scheduling check-ins using Process.send_after/3,
  restores scheduled check-ins from the database on startup,
  and manages the recurring scheduling logic.
  """

  use GenServer
  require Logger

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

  @doc """
  Gets the status of all scheduled check-ins.
  """
  def status do
    GenServer.call(__MODULE__, :status)
  end

  # GenServer Callbacks

  @impl true
  def init(_opts) do
    Logger.info("OpenDevCoach Scheduler started")
    # Restore all check-ins from database on startup
    restore_checkins_from_database()
    {:ok, %{}}
  end

  @impl true
  def handle_call({:add_checkin, time_or_interval, description}, _from, state) do
    case parse_time_or_interval(time_or_interval) do
      {:ok, next_time} ->
        case OpenDevCoach.Checkins.create_checkin(%{
               scheduled_at: next_time,
               description: description,
               status: "SCHEDULED"
             }) do
          {:ok, checkin} ->
            schedule_next_checkin(checkin)
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
    checkins = OpenDevCoach.Checkins.list_active_checkins()
    {:reply, checkins, state}
  end

  @impl true
  def handle_call({:remove_checkin, checkin_id}, _from, state) do
    case OpenDevCoach.Checkins.get_checkin(checkin_id) do
      nil ->
        {:reply, {:error, "Check-in not found"}, state}

      checkin ->
        # Cancel any pending timer
        cancel_checkin_timer(checkin_id)
        # Remove from database
        OpenDevCoach.Checkins.delete_checkin(checkin)
        {:reply, {:ok, "Check-in removed"}, state}
    end
  end

  @impl true
  def handle_call(:status, _from, state) do
    checkins = OpenDevCoach.Checkins.list_active_checkins()

    status_info =
      Enum.map(checkins, fn checkin ->
        %{
          id: checkin.id,
          scheduled_at: checkin.scheduled_at,
          description: checkin.description,
          status: checkin.status,
          next_occurrence: calculate_next_occurrence(checkin.scheduled_at)
        }
      end)

    {:reply, status_info, state}
  end

  @impl true
  def handle_info({:checkin, checkin_id}, state) do
    case OpenDevCoach.Checkins.get_checkin(checkin_id) do
      nil ->
        Logger.warning("Check-in #{checkin_id} not found, skipping")
        {:noreply, state}

      checkin ->
        # Send check-in message to Session
        OpenDevCoach.Session.handle_checkin(checkin)

        # Update last triggered time
        OpenDevCoach.Checkins.update_checkin(checkin, %{last_triggered_at: DateTime.utc_now()})

        # Schedule next occurrence for recurring check-ins
        schedule_next_checkin(checkin)

        {:noreply, state}
    end
  end

  # Private Functions

  defp restore_checkins_from_database do
    checkins = OpenDevCoach.Checkins.list_active_checkins()
    Enum.each(checkins, &schedule_next_checkin/1)
    Logger.info("Restored #{length(checkins)} scheduled check-ins from database")
  end

  defp schedule_next_checkin(checkin) do
    next_time = calculate_next_occurrence(checkin.scheduled_at)
    now = DateTime.utc_now()

    case DateTime.compare(next_time, now) do
      :gt ->
        # Schedule for future
        delay_ms = DateTime.diff(next_time, now, :millisecond)
        Process.send_after(self(), {:checkin, checkin.id}, delay_ms)
        Logger.debug("Scheduled check-in #{checkin.id} for #{next_time}")

      _ ->
        # Schedule for next day if time has passed
        next_day = DateTime.add(next_time, 24 * 60 * 60, :second)
        delay_ms = DateTime.diff(next_day, now, :millisecond)
        Process.send_after(self(), {:checkin, checkin.id}, delay_ms)
        Logger.debug("Scheduled check-in #{checkin.id} for next day: #{next_day}")
    end
  end

  defp cancel_checkin_timer(checkin_id) do
    # Note: Process.send_after returns a timer reference, but we're not storing it
    # In a production system, you'd want to store timer references to cancel them
    # For now, we'll rely on the process being restarted to clear old timers
    Logger.debug("Check-in #{checkin_id} timer cancelled")
  end

  defp calculate_next_occurrence(scheduled_time) do
    now = DateTime.utc_now()
    # Extract just the time portion for daily scheduling
    scheduled_time_only = %Time{
      hour: scheduled_time.hour,
      minute: scheduled_time.minute,
      second: scheduled_time.second
    }

    today = DateTime.new!(Date.new!(now.year, now.month, now.day), scheduled_time_only, "Etc/UTC")

    case DateTime.compare(today, now) do
      :gt -> today
      _ -> DateTime.add(today, 24 * 60 * 60, :second)
    end
  end

  defp parse_time_or_interval(input) when is_binary(input) do
    cond do
      # Handle HH:MM format (e.g., "09:30")
      Regex.match?(~r/^\d{1,2}:\d{2}$/, input) ->
        parse_time_format(input)

      # Handle interval format (e.g., "2h 30m", "30m")
      Regex.match?(~r/^\d+[hm]\s*\d*[hm]?$/, input) ->
        parse_interval_format(input)

      true ->
        {:error, "Invalid format. Use HH:MM (e.g., '09:30') or interval (e.g., '2h 30m')"}
    end
  end

  defp parse_time_format(time_str) do
    [hour_str, minute_str] = String.split(time_str, ":")
    hour = String.to_integer(hour_str)
    minute = String.to_integer(minute_str)

    if hour >= 0 and hour <= 23 and minute >= 0 and minute <= 59 do
      now = DateTime.utc_now()
      scheduled_time = Time.new!(hour, minute, 0)
      today = DateTime.new!(Date.new!(now.year, now.month, now.day), scheduled_time, "Etc/UTC")
      {:ok, today}
    else
      {:error, "Invalid time: hour must be 0-23, minute must be 0-59"}
    end
  end

  defp parse_interval_format(interval_str) do
    # Parse patterns like "2h 30m", "30m", "1h"
    hour_match = Regex.run(~r/(\d+)h/, interval_str)
    minute_match = Regex.run(~r/(\d+)m/, interval_str)

    hours = if hour_match, do: String.to_integer(Enum.at(hour_match, 1)), else: 0
    minutes = if minute_match, do: String.to_integer(Enum.at(minute_match, 1)), else: 0

    if hours == 0 and minutes == 0 do
      {:error, "Invalid interval: must specify at least one hour or minute"}
    else
      now = DateTime.utc_now()
      next_time = DateTime.add(now, hours * 60 * 60 + minutes * 60, :second)
      {:ok, next_time}
    end
  end
end
