defmodule OpenDevCoach.CLI.Views.TaskView do
  @moduledoc """
  View layer for formatting Task data for console output.

  This module provides formatting functions specifically for tasks,
  keeping presentation logic separate from business logic.
  """

  alias OpenDevCoach.Tasks.Task

  @doc """
  Formats a list of tasks for display in the console.
  """
  @spec format([Task.t()]) :: String.t()
  def format(tasks) when is_list(tasks) do
    case tasks do
      [] ->
        "No tasks found. Add one with `/task add <description>`"

      _ ->
        tasks
        |> Enum.with_index(1)
        |> Enum.map_join("\n", fn {task, index} ->
          status_emoji = get_status_emoji(task.status)
          "  #{index}. #{status_emoji} #{task.description} [#{task.status}]"
        end)
        |> then(&"Your Tasks:\n#{&1}")
    end
  end

  # Private helper functions

  defp get_status_emoji(status) do
    case status do
      # Yellow circle
      "PENDING" -> "\e[33m●\e[0m"
      # Blue circle
      "IN-PROGRESS" -> "\e[34m●\e[0m"
      # Magenta circle
      "ON-HOLD" -> "\e[35m●\e[0m"
      # Green circle
      "COMPLETED" -> "\e[32m●\e[0m"
      # White circle
      _ -> "\e[37m●\e[0m"
    end
  end
end
