defmodule OpenDevCoach.CLI.CheckinCommands do
  @moduledoc """
  Command handler for check-in management in the OpenDevCoach REPL.

  This module provides the check-in command interface, handling scheduling,
  listing, and management of check-ins.
  """

  alias OpenDevCoach.CLI.Views.CheckinView
  alias OpenDevCoach.Servers.Scheduler

  @doc """
  Dispatches check-in commands to the appropriate handler.
  """
  def dispatch(args) do
    case args do
      ["add", time | description_parts] ->
        description = Enum.join(description_parts, " ")
        add_checkin(time, description)

      ["list"] ->
        list_checkins([])

      ["remove", id_str] ->
        case Integer.parse(id_str) do
          {id, _} -> remove_checkin(id)
          :error -> {:error, "Invalid check-in ID. Please provide a number."}
        end

      _ ->
        {:error,
         """
         Invalid check-in command. Available options:
           /checkin add <time> [description]  - Schedule a check-in
           /checkin list                      - List all check-ins
           /checkin remove <id>               - Remove a check-in

         Time formats:
           HH:MM (e.g., '09:30' for 9:30 AM)
           Xh Ym (e.g., '2h 30m' for 2 hours 30 minutes from now)
         """}
    end
  end

  @doc """
  Adds a new scheduled check-in.
  """
  def add_checkin(time, description) do
    case Scheduler.add_checkin(time, description) do
      {:ok, _checkin_id} ->
        checkins = Scheduler.list_checkins()
        formatted = CheckinView.format(checkins)
        {:ok, formatted}

      {:error, reason} ->
        {:error, "Failed to schedule check-in: #{reason}"}
    end
  end

  @doc """
  Lists all scheduled check-ins.
  """
  def list_checkins(_args) do
    checkins = Scheduler.list_checkins()
    formatted = CheckinView.format(checkins)
    {:ok, formatted}
  end

  @doc """
  Removes a scheduled check-in by ID.
  """
  def remove_checkin(checkin_id) do
    case Scheduler.remove_checkin(checkin_id) do
      {:ok, message} ->
        {:ok, message}

      {:error, reason} ->
        {:error, "Failed to remove check-in: #{reason}"}
    end
  end
end
