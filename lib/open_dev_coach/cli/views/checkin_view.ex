defmodule OpenDevCoach.CLI.Views.CheckinView do
  @moduledoc """
  View layer for formatting Checkin data for console output.

  This module provides formatting functions specifically for check-ins,
  keeping presentation logic separate from business logic.
  """

  alias OpenDevCoach.Checkins.Checkin

  @doc """
  Formats a list of check-ins for display in the console.
  """
  @spec format([{Checkin.t(), integer()}]) :: String.t()
  def format(checkins) when is_list(checkins) do
    case checkins do
      [] ->
        "No scheduled check-ins found. Add one with `/checkin add <time> [description]`"

      _ ->
        checkins
        |> Enum.map_join("\n", fn {checkin, index} ->
          scheduled_str = Timex.format!(checkin.scheduled_at, "%Y-%m-%d %I:%M%p", :strftime)
          desc = if checkin.description, do: checkin.description, else: ""
          "  #{index}. #{scheduled_str}#{desc} (#{checkin.status})"
        end)
        |> then(&"Scheduled Check-ins:\n#{&1}")
    end
  end
end
