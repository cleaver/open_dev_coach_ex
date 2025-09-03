defmodule OpenDevCoach.CLI.ConfigCommands do
  @moduledoc """
  Command handler for configuration management in OpenDevCoach.

  This module handles all `/config` subcommands, delegating the actual
  logic to the Session GenServer.
  """

  alias OpenDevCoach.Configuration.Config
  alias OpenDevCoach.Session

  @doc """
  Dispatches configuration commands to the appropriate handler.
  """
  def dispatch(["set", key, value]), do: set_config(key, value)
  def dispatch(["get", key]), do: get_config(key)
  def dispatch(["list"]), do: list_configs()
  def dispatch(["reset"]), do: reset_config()
  def dispatch(["keys"]), do: show_valid_keys()
  def dispatch(["test"]), do: test_config()
  def dispatch(["timezone"]), do: show_timezone()
  def dispatch(["timezone", timezone]), do: set_timezone(timezone)

  def dispatch(_),
    do: {:error, "Usage: /config <set|get|list|reset|keys|test|timezone> [key] [value]"}

  @doc """
  Sets a configuration key-value pair.
  """
  def set_config(key, value) do
    case Session.set_config(key, value) do
      {:ok, message} -> {:ok, message}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Gets a configuration value by key.
  """
  def get_config(key) do
    case Session.get_config(key) do
      {:ok, message} -> {:ok, message}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Lists all configuration settings.
  """
  def list_configs do
    case Session.list_configs() do
      {:ok, message} -> {:ok, message}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Resets all configuration to default values.
  """
  def reset_config do
    case Session.reset_config() do
      {:ok, message} -> {:ok, message}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Shows the list of valid configuration keys.
  """
  def show_valid_keys do
    keys = Config.valid_keys()

    message = """
    Valid Configuration Keys:
    #{keys |> Enum.map_join("\n", &"  • #{&1}")}

    Use `/config set <key> <value>` to set a configuration.
    """

    {:ok, message}
  end

  @doc """
  Tests the current AI configuration by sending a simple message.
  """
  def test_config do
    case Session.test_ai_config() do
      {:ok, message} -> {:ok, message}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Shows the current timezone setting.
  """
  def show_timezone do
    timezone = Application.get_env(:open_dev_coach, :timezone, "America/New_York")
    {:ok, "Current timezone: #{timezone}"}
  end

  @doc """
  Sets the timezone for the application.
  """
  def set_timezone(timezone) do
    # Validate timezone
    case validate_timezone(timezone) do
      {:ok, _} ->
        # Update the application config
        Application.put_env(:open_dev_coach, :timezone, timezone)
        {:ok, "Timezone set to: #{timezone}"}

      {:error, reason} ->
        {:error, "Invalid timezone: #{reason}"}
    end
  end

  # Private functions

  defp validate_timezone(timezone) when is_binary(timezone) do
    if timezone in Timex.timezones() do
      {:ok, timezone}
    else
      {:error, "Unsupported timezone. Use one of: #{Enum.join(Timex.timezones(), ", ")}"}
    end
  end

  defp validate_timezone(_), do: {:error, "Timezone must be a string"}
end
