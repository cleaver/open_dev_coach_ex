defmodule OpenDevCoach.Configuration do
  @moduledoc """
  Context module for managing application configuration.

  This module provides functions to get, set, list, and reset configuration
  values stored in the database. Configuration keys include AI provider settings,
  models, API keys, and custom prompts.
  """
  require Logger

  alias OpenDevCoach.Configuration.Config
  alias OpenDevCoach.Helpers.Repo, as: RepoHelper
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
  Prepares an update changeset for configuration.
  This is the "validation" step.
  """
  def prepare_update_changeset(%Config{} = config, attrs) do
    Config.changeset(config, attrs)
  end

  @doc """
  Applies a valid changeset and returns the new struct.
  Use this for in-memory state updates.
  """
  def apply_update_changeset(%Ecto.Changeset{valid?: true} = changeset) do
    Ecto.Changeset.apply_action!(changeset, :update)
  end

  def apply_update_changeset(%Ecto.Changeset{} = changeset), do: {:error, changeset}

  @doc """
  Persists a changeset to the database.
  This is the "persistence" step for an async Task.
  """
  def persist_update_changeset(%Ecto.Changeset{} = changeset) do
    RepoHelper.retry_with_backoff(fn ->
      Repo.update(changeset)
    end)
  end

  @doc """
  Sets or updates a configuration key-value pair.

  If the key already exists, it will be updated. If it doesn't exist,
  a new configuration entry will be created.
  """
  def set_config(key, value) when is_binary(key) and is_binary(value) do
    set_config_internal(key, value)
  end

  defp set_config_internal(key, value) when is_binary(key) and is_binary(value) do
    case Repo.get_by(Config, key: key) do
      nil ->
        RepoHelper.retry_with_backoff(fn ->
          %Config{}
          |> Config.changeset(%{key: key, value: value})
          |> Repo.insert()
        end)

      existing_config ->
        RepoHelper.retry_with_backoff(fn ->
          existing_config
          |> Config.changeset(%{value: value})
          |> Repo.update()
        end)
    end
  end

  @doc """
  Lists all configuration entries as a list of Config structs.
  Used for GenServer state management.
  """
  def list_configs do
    Repo.all(Config)
  end

  @doc """
  Creates a new configuration entry.
  """
  def create_config(attrs \\ %{}) do
    RepoHelper.retry_with_backoff(fn ->
      %Config{}
      |> Config.changeset(attrs)
      |> Repo.insert()
    end)
  end

  @doc """
  Resets all configuration to default values.

  This removes all custom configurations from the database.
  """
  def reset_config do
    RepoHelper.retry_with_backoff(fn ->
      Config
      |> Repo.delete_all()
    end)

    {:ok, "All configurations have been reset"}
  end
end
