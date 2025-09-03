defmodule OpenDevCoach.Configuration do
  @moduledoc """
  Context module for managing application configuration.

  This module provides functions to get, set, list, and reset configuration
  values stored in the database. Configuration keys include AI provider settings,
  models, API keys, and custom prompts.
  """

  import Ecto.Query

  alias OpenDevCoach.Configuration.Config
  alias OpenDevCoach.Repo

  @doc """
  Retrieves a configuration value by key.

  Returns the value if the key exists, nil otherwise.
  """
  def get_config(key) when is_binary(key) do
    case Repo.get_by(Config, key: key) do
      nil -> nil
      config -> config.value
    end
  end

  @doc """
  Sets or updates a configuration key-value pair.

  If the key already exists, it will be updated. If it doesn't exist,
  a new configuration entry will be created.
  """
  def set_config("timezone", value) do
    case validate_timezone(value) do
      {:ok, _} -> set_config("timezone", value)
      {:error, reason} -> {:error, reason}
    end
  end

  def set_config(key, value) when is_binary(key) and is_binary(value) do
    case Repo.get_by(Config, key: key) do
      nil ->
        %Config{}
        |> Config.changeset(%{key: key, value: value})
        |> Repo.insert()

      existing_config ->
        existing_config
        |> Config.changeset(%{value: value})
        |> Repo.update()
    end
  end

  defp validate_timezone(timezone) when is_binary(timezone) do
    if timezone in Timex.timezones() do
      {:ok, timezone}
    else
      {:error, "Invalid timezone: #{timezone}. Use one of the supported timezones."}
    end
  end

  @doc """
  Lists all current configuration settings.

  Returns a map of configuration keys to values.
  """
  def list_configs do
    Config
    |> select([c], {c.key, c.value})
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Resets all configuration to default values.

  This removes all custom configurations from the database.
  """
  def reset_config do
    Config
    |> Repo.delete_all()

    {:ok, "All configurations have been reset"}
  end
end
