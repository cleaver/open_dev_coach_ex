defmodule OpenDevCoach.Servers.Session do
  @moduledoc """
  Public API for the Session functionality.

  This module provides the public interface for the Session GenServer.
  It delegates all calls to the appropriate GenServer functions.
  """

  import OpenDevCoach.Helpers.Future

  defp server_name, do: __MODULE__

  @doc """
  Returns a child specification for the Session GenServer.
  """
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  @doc """
  Starts the Session GenServer.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__.Server, opts, name: server_name())
  end

  @doc """
  Handles a check-in trigger from the scheduler.

  This function is called when a scheduled check-in time is reached.
  It will gather context and call the AI system for a coaching response.
  """
  def handle_checkin(checkin) do
    GenServer.call(server_name(), {:handle_checkin, checkin})
  end

  # Task Management Functions

  @doc """
  Adds a new task to the system.
  """
  def add_task(description) do
    future(:add_task, "Make tasks pluggable")
    GenServer.call(server_name(), {:add_task, description})
  end

  @doc """
  Lists all tasks in the system.
  """
  def list_tasks do
    future(:list_tasks, "Make tasks pluggable")
    GenServer.call(server_name(), {:list_tasks})
  end

  @doc """
  Starts a task (marks as IN-PROGRESS) by task order number.
  """
  def start_task(task_order) do
    future(:start_task, "Make tasks pluggable")
    GenServer.call(server_name(), {:start_task, task_order})
  end

  @doc """
  Completes a task (marks as COMPLETED) by task order number.
  """
  def complete_task(task_order) do
    future(:complete_task, "Make tasks pluggable")
    GenServer.call(server_name(), {:complete_task, task_order})
  end

  @doc """
  Removes a task from the system by task order number.
  """
  def remove_task(task_order) do
    future(:remove_task, "Make tasks pluggable")
    GenServer.call(server_name(), {:remove_task, task_order})
  end

  @doc """
  Creates a backup of all tasks in markdown format.
  """
  def backup_tasks do
    future(:backup_tasks, "Make tasks pluggable")
    GenServer.call(server_name(), {:backup_tasks})
  end

  # Configuration Management Functions

  @doc """
  Gets a configuration value by key.
  """
  def get_config(key) do
    GenServer.call(server_name(), {:get_config, key})
  end

  @doc """
  Sets a configuration key-value pair.
  """
  def set_config(key, value) do
    GenServer.call(server_name(), {:set_config, key, value})
  end

  @doc """
  Lists all configuration settings.
  """
  def list_configs do
    GenServer.call(server_name(), {:list_configs})
  end

  @doc """
  Resets all configuration to defaults.
  """
  def reset_config do
    GenServer.call(server_name(), {:reset_config})
  end

  # AI Chat Functions

  @doc """
  Sends a message to the AI and manages conversation history.
  """
  def chat_with_ai(user_message) do
    GenServer.call(server_name(), {:chat_with_ai, user_message})
  end

  @doc """
  Tests the AI configuration by sending a simple message.
  """
  def test_ai_config do
    GenServer.call(server_name(), {:test_ai_config})
  end
end
