defmodule OpenDevCoach.Servers.Scheduler.Impl do
  @moduledoc """
  Pure business logic for the Scheduler functionality.

  This module contains all the application logic without any GenServer concerns.
  It can be easily tested and reused independently of the server implementation.
  """

  require Logger
  alias OpenDevCoach.Checkins
  alias OpenDevCoach.Checkins.Checkin
  alias OpenDevCoach.Helpers.Date, as: DateHelper
  alias OpenDevCoach.Servers.Session

  @type scheduler_state() :: %{
          checkins: [Checkin.t()]
        }

  @doc """
  Initializes the scheduler state.
  """
  def init(_opts) do
    Logger.info("OpenDevCoach Scheduler started")

    # Handle missed check-ins and restore active ones from database
    handle_missed_checkins()
    checkins = Checkins.list_scheduled_checkins()
    restore_checkins(checkins)
    %{checkins: checkins}
  end

  @doc """
  Adds a new check-in to the scheduler.

  Parameters:
    - state: Current scheduler state
    - time_or_interval: Either "HH:MM" format or interval like "2h 30m"
    - description: Optional description for the check-in

  Returns:
    - {{:ok, checkin_id}, new_state} on success
    - {{:error, reason}, state} on failure
  """
  def add_checkin(state, time_or_interval, description \\ nil) do
    case parse_time_or_interval(time_or_interval) do
      {:ok, next_time} ->
        {checkin, new_state} = add_checkin_to_state(state, next_time, description)

        Task.start(fn ->
          Checkins.create_checkin(checkin)
        end)

        list_checkins(new_state)

      {:error, reason} ->
        {{:error, reason}, state}
    end
  end

  defp add_checkin_to_state(state, next_time, description) do
    checkin = %Checkin{
      id: Ecto.UUID.generate(),
      scheduled_at: next_time,
      description: description,
      status: "SCHEDULED"
    }

    all_checkins = Map.get(state, :checkins, [])
    new_checkins = all_checkins ++ [checkin]
    {checkin, %{state | checkins: new_checkins}}
  end

  @doc """
  Lists all scheduled check-ins.

  Parameters:
    - state: Current scheduler state

  Returns: - {checkins, state} where checkins is the list of active check-ins with their ordinal
  """
  @spec list_checkins(scheduler_state()) ::
          {{:ok, list({Checkin.t(), integer()})}, scheduler_state()}
  def list_checkins(state) do
    checkins = sort_checkins_with_ordinal(state)

    {{:ok, checkins}, state}
  end

  defp sort_checkins_with_ordinal(state) do
    state
    |> Map.get(:checkins, [])
    |> Enum.sort_by(& &1.scheduled_at)
    |> Enum.with_index()
    |> Enum.map(fn {checkin, index} ->
      {checkin, index + 1}
    end)
  end

  @doc """
  Removes a scheduled check-in by ID.

  Parameters:
    - state: Current scheduler state
    - checkin_ordinal: Ordinal of the check-in to remove

  Returns:
    - {{:ok, message}, new_state} on success
    - {{:error, reason}, state} on failure
  """
  def remove_checkin(state, checkin_ordinal) do
    {checkin, new_state} = remove_checkin_from_state(state, checkin_ordinal)

    Task.start(fn ->
      Checkins.delete_checkin(checkin)
    end)

    {{:ok, "Check-in removed"}, new_state}
  end

  defp remove_checkin_from_state(state, checkin_ordinal) when is_integer(checkin_ordinal) do
    sorted_checkins = sort_checkins_with_ordinal(state)
    {{checkin, _}, new_checkins} = List.pop_at(sorted_checkins, checkin_ordinal - 1)
    {checkin, %{state | checkins: new_checkins}}
  end

  defp remove_checkin_from_state(_, _) do
    {:error, "Invalid checkin ordinal"}
  end

  defp update_checkin(state, checkin, attrs) do
    checkin_changeset = Checkin.changeset(checkin, attrs)

    case Ecto.Changeset.apply_action(checkin_changeset, :update) do
      {:ok, new_checkin} ->
        {new_checkin, %{state | checkins: new_checkin_list}}

      {:error, changeset} ->
        Logger.error("Failed to update check-in: #{inspect(changeset)}")
        state
    end
  end

  @doc """
  Handles a check-in trigger from the timer.

  Parameters:
    - state: Current scheduler state
    - checkin_id: ID of the check-in that was triggered

  Returns:
    - {new_state, new_state} (state doesn't change for check-in handling)
  """
  def handle_checkin_trigger(state, checkin_id) do
    case Enum.find(state.checkins, &(&1.id == checkin_id)) do
      nil ->
        Logger.warning("Check-in #{checkin_id} not found, skipping")
        {state, state}

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

        {state, state}
    end
  end

  defp handle_missed_checkins do
    {update_count, _} = Checkins.mark_past_scheduled_checkins_as_skipped()

    if update_count > 0 do
      Logger.info("Marked #{update_count} missed check-ins as SKIPPED")
    end
  end

  defp restore_checkins(scheduled_checkins) do
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
