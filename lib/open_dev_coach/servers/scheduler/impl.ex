defmodule OpenDevCoach.Servers.Scheduler.Impl do
  @moduledoc """
  Pure business logic for the Scheduler functionality.

  This module contains all the application logic without any GenServer concerns.
  It can be easily tested and reused independently of the server implementation.
  """

  require Logger

  import OpenDevCoach.Helpers.Persistence

  alias OpenDevCoach.Checkins
  alias OpenDevCoach.Checkins.Checkin
  alias OpenDevCoach.Helpers.Date, as: DateHelper
  alias OpenDevCoach.Helpers.List, as: ListHelper
  alias OpenDevCoach.Servers.Session

  @type scheduler_state() :: %{
          checkins: [Checkin.t()],
          timers: [reference()]
        }

  @doc """
  Initializes the scheduler state.
  """
  def init(_opts) do
    Logger.info("OpenDevCoach Scheduler started")
    handle_missed_checkins()

    _state =
      %{checkins: Checkins.list_scheduled_checkins(), timers: []}
      |> reload_scheduled_checkins()
  end

  @doc """
  Adds a new check-in to the scheduler.

  Parameters:
    - state: Current scheduler state
    - time_or_interval: Either "HH:MM" format or interval like "2h 30m"
    - description: Optional description for the check-in

  Returns:
    - {{:ok, checkin, list_of_sorted_checkins}, new_state} on success
    - {{:error, reason}, state} on failure
  """
  def add_checkin(state, time_or_interval, description \\ nil) do
    case parse_time_or_interval(time_or_interval) do
      {:ok, next_time} ->
        attrs = %{
          id: Ecto.UUID.generate(),
          scheduled_at: next_time,
          description: description,
          status: "SCHEDULED"
        }

        {checkin, new_state_with_checkin} =
          add_in_memory_and_persist_async(
            state,
            attrs,
            collection_key: :checkins,
            struct_module: Checkin,
            persist_function: &Checkins.create_checkin/1
          )

        timer = schedule_checkin(checkin)
        new_state = %{new_state_with_checkin | timers: [timer | state.timers]}

        list_of_sorted_checkins = sort_checkins_with_ordinal(new_state)
        {{:ok, checkin, list_of_sorted_checkins}, new_state}

      {:error, reason} ->
        {{:error, reason}, state}
    end
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

    if async_persistence?(),
      do: Task.start(fn -> Checkins.delete_checkin(checkin) end),
      else: Checkins.delete_checkin(checkin)

    {{:ok, "Check-in removed"}, new_state}
  end

  defp remove_checkin_from_state(state, checkin_ordinal) when is_integer(checkin_ordinal) do
    sorted_checkins = sort_checkins_with_ordinal(state)
    {checkin, _ordinal} = Enum.at(sorted_checkins, checkin_ordinal - 1)

    new_checkins =
      state
      |> Map.get(:checkins, [])
      |> Enum.reject(&(&1.id == checkin.id))

    {checkin, %{state | checkins: new_checkins}}
  end

  defp remove_checkin_from_state(_, _) do
    {:error, "Invalid checkin ordinal"}
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
        Session.handle_checkin(checkin)

        {updated_checkin, new_state} =
          update_checkin(state, checkin, %{
            last_triggered_at: DateHelper.local_datetime_now(),
            status: "COMPLETED"
          })

        Logger.info("Check-in #{checkin_id} completed and marked as COMPLETED")

        {updated_checkin, new_state}
    end
  end

  defp update_checkin(state, checkin, attrs) do
    update_in_memory_and_persist_async(
      state,
      checkin,
      attrs,
      collection_key: :checkins,
      prepare_changeset: &Checkins.prepare_update_changeset/2,
      apply_changeset: &Checkins.apply_update_changeset/1,
      persist_changeset: &Checkins.persist_update_changeset/1
    )
  end

  defp handle_missed_checkins do
    # We should only call this at genserver init.
    {update_count, _} = Checkins.mark_past_scheduled_checkins_as_skipped()

    if update_count > 0 do
      Logger.info("Marked #{update_count} missed check-ins as SKIPPED")
    end
  end

  defp reload_scheduled_checkins(state) do
    state
    |> Map.get(:timers, [])
    |> cancel_all_checkin_timers()

    timers =
      state
      |> Map.get(:checkins, [])
      |> restore_checkins()

    %{state | timers: timers}
  end

  defp restore_checkins(scheduled_checkins) do
    Logger.info("Restoring #{length(scheduled_checkins)} scheduled check-ins")
    ListHelper.map_filter(scheduled_checkins, &schedule_checkin/1, &(&1 != nil))
  end

  defp schedule_checkin(checkin) do
    next_time = checkin.scheduled_at
    now = DateHelper.local_datetime_now()

    if DateTime.compare(next_time, now) == :gt do
      delay_ms = DateTime.diff(next_time, now, :millisecond)
      Logger.info("Scheduling check-in #{checkin.id} for #{next_time}")
      Process.send_after(self(), {:checkin, checkin.id}, delay_ms)
    end
  end

  defp cancel_all_checkin_timers(timer_list), do: Enum.each(timer_list, &Process.cancel_timer/1)

  defp parse_time_or_interval(input) when is_binary(input) do
    DateHelper.parse_time_or_interval(input)
  end

  defp async_persistence? do
    Application.get_env(:open_dev_coach, :async_persistence, true)
  end
end
