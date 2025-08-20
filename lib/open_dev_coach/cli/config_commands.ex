defmodule OpenDevCoach.CLI.ConfigCommands do
  @moduledoc """
  Command handler for configuration management in OpenDevCoach.

  This module handles all `/config` subcommands, delegating the actual
  logic to the Session GenServer.
  """

  alias OpenDevCoach.Session

  @doc """
  Dispatches configuration commands to the appropriate handler.
  """
  def dispatch(args) do
    case args do
      ["set", key, value] -> set_config(key, value)
      ["get", key] -> get_config(key)
      ["list"] -> list_configs()
      ["reset"] -> reset_config()
      _ -> {:error, "Usage: /config <set|get|list|reset> [key] [value]"}
    end
  end

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
end
