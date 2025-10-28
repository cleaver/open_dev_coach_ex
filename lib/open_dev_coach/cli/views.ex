defmodule OpenDevCoach.CLI.Views do
  @moduledoc """
  Handles formatting data for console output.

  This module provides view functions that take pure data structures
  and format them for display in the CLI. This separates presentation
  concerns from business logic.
  """

  alias OpenDevCoach.Tasks.Task

  @doc """
  Formats a list of tasks for display in the console.
  """
  @spec format_tasks([Task.t()]) :: String.t()
  def format_tasks(tasks) do
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

  @doc """
  Formats a configuration map for display in the console.
  """
  @spec format_configs(map()) :: String.t()
  def format_configs(configs) do
    case configs do
      configs when map_size(configs) == 0 ->
        "No configurations set. Use `/config set <key> <value>` to add some."

      _ ->
        configs
        |> Enum.map_join("\n", fn {key, value} ->
          "  #{key}: #{maybe_redact_value(key, value)}"
        end)
        |> then(&"Current Configurations:\n#{&1}")
    end
  end

  @doc """
  Formats a single configuration key-value pair for display.
  """
  @spec format_config(String.t(), String.t()) :: String.t()
  def format_config(key, value) do
    "#{key}: #{value}"
  end

  @doc """
  Formats a configuration message for display.
  """
  @spec format_config_message(String.t()) :: String.t()
  def format_config_message(message) do
    message
  end

  @doc """
  Formats configuration not found message.
  """
  @spec format_config_not_found(String.t()) :: String.t()
  def format_config_not_found(key) do
    "Configuration key '#{key}' not found"
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

  defp maybe_redact_value("ai_api_key", _value), do: "***"
  defp maybe_redact_value(_key, value), do: value
end
