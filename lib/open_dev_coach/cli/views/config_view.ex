defmodule OpenDevCoach.CLI.Views.ConfigView do
  @moduledoc """
  View layer for formatting Configuration data for console output.

  This module provides formatting functions specifically for configuration,
  keeping presentation logic separate from business logic.
  """

  @doc """
  Formats a configuration map for display in the console.
  """
  @spec format(map()) :: String.t()
  def format(configs) when is_map(configs) do
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
  @spec format_single(String.t(), String.t()) :: String.t()
  def format_single(key, value) do
    "#{key}: #{maybe_redact_value(key, value)}"
  end

  @doc """
  Formats a configuration message for display.
  """
  @spec format_message(String.t()) :: String.t()
  def format_message(message) do
    message
  end

  @doc """
  Formats configuration not found message.
  """
  @spec format_not_found(String.t()) :: String.t()
  def format_not_found(key) do
    "Configuration key '#{key}' not found"
  end

  # Private helper functions

  defp maybe_redact_value("ai_api_key", _value), do: "***"
  defp maybe_redact_value(_key, value), do: value
end
