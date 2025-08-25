defmodule OpenDevCoach.Session do
  @moduledoc """
  Main session GenServer for managing OpenDevCoach application state.

  This module handles the core application logic and state management,
  serving as the central coordinator for all operations.
  """

  use GenServer
  require Logger
  alias OpenDevCoach.Tasks
  alias OpenDevCoach.Configuration
  alias OpenDevCoach.AI
  alias OpenDevCoach.AgentHistory

  @doc """
  Starts the Session GenServer.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Handles a check-in trigger from the scheduler.

  This function is called when a scheduled check-in time is reached.
  It will gather context and call the AI system for a coaching response.
  """
  def handle_checkin(checkin) do
    GenServer.cast(__MODULE__, {:handle_checkin, checkin})
  end

  @impl true
  def init(_opts) do
    Logger.info("OpenDevCoach Session started")
    {:ok, %{}}
  end

  # Task Management Functions

  @doc """
  Adds a new task to the system.
  """
  def add_task(description) do
    GenServer.call(__MODULE__, {:add_task, description})
  end

  @doc """
  Lists all tasks in the system.
  """
  def list_tasks do
    GenServer.call(__MODULE__, {:list_tasks})
  end

  @doc """
  Starts a task (marks as IN-PROGRESS).
  """
  def start_task(task_id) do
    GenServer.call(__MODULE__, {:start_task, task_id})
  end

  @doc """
  Completes a task (marks as COMPLETED).
  """
  def complete_task(task_id) do
    GenServer.call(__MODULE__, {:complete_task, task_id})
  end

  @doc """
  Removes a task from the system.
  """
  def remove_task(task_id) do
    GenServer.call(__MODULE__, {:remove_task, task_id})
  end

  @doc """
  Creates a backup of all tasks in markdown format.
  """
  def backup_tasks do
    GenServer.call(__MODULE__, {:backup_tasks})
  end

  # Configuration Management Functions

  @doc """
  Gets a configuration value by key.
  """
  def get_config(key) do
    GenServer.call(__MODULE__, {:get_config, key})
  end

  @doc """
  Sets a configuration key-value pair.
  """
  def set_config(key, value) do
    GenServer.call(__MODULE__, {:set_config, key, value})
  end

  @doc """
  Lists all configuration settings.
  """
  def list_configs do
    GenServer.call(__MODULE__, {:list_configs})
  end

  @doc """
  Resets all configuration to defaults.
  """
  def reset_config do
    GenServer.call(__MODULE__, {:reset_config})
  end

  # AI Chat Functions

  @doc """
  Sends a message to the AI and manages conversation history.
  """
  def chat_with_ai(user_message) do
    GenServer.call(__MODULE__, {:chat_with_ai, user_message})
  end

  @doc """
  Tests the AI configuration by sending a simple message.
  """
  def test_ai_config do
    GenServer.call(__MODULE__, {:test_ai_config})
  end

  @impl true
  def handle_call({:add_task, description}, _from, state) do
    case Tasks.add_task(description) do
      {:ok, task} ->
        message = "Task added: #{task.description} [ID: #{task.id}]"
        {:reply, {:ok, message}, state}

      {:error, reason} ->
        {:reply, {:error, "Failed to add task: #{reason}"}, state}
    end
  end

  def handle_call({:list_tasks}, _from, state) do
    tasks = Tasks.list_tasks()
    message = format_task_list(tasks)
    {:reply, {:ok, message}, state}
  end

  def handle_call({:start_task, task_id}, _from, state) do
    case Tasks.update_task_status(task_id, "IN-PROGRESS") do
      {:ok, _} ->
        message = "Task #{task_id} started and other tasks put on hold"
        {:reply, {:ok, message}, state}

      {:error, reason} ->
        {:reply, {:error, "Failed to start task: #{reason}"}, state}
    end
  end

  def handle_call({:complete_task, task_id}, _from, state) do
    case Tasks.update_task_status(task_id, "COMPLETED") do
      {:ok, _} ->
        message = "Task #{task_id} marked as completed"
        {:reply, {:ok, message}, state}

      {:error, reason} ->
        {:reply, {:error, "Failed to complete task: #{reason}"}, state}
    end
  end

  def handle_call({:remove_task, task_id}, _from, state) do
    case Tasks.remove_task(task_id) do
      {:ok, _} ->
        message = "Task #{task_id} removed"
        {:reply, {:ok, message}, state}

      {:error, reason} ->
        {:reply, {:error, "Failed to remove task: #{reason}"}, state}
    end
  end

  def handle_call({:backup_tasks}, _from, state) do
    case create_task_backup() do
      {:ok, filename} ->
        message = "Tasks backed up to #{filename}"
        {:reply, {:ok, message}, state}

      {:error, reason} ->
        {:reply, {:error, "Failed to backup tasks: #{reason}"}, state}
    end
  end

  # Configuration Management Callbacks

  def handle_call({:get_config, key}, _from, state) do
    case Configuration.get_config(key) do
      nil ->
        {:reply, {:ok, "Configuration key '#{key}' not found"}, state}

      value ->
        {:reply, {:ok, "#{key}: #{value}"}, state}
    end
  end

  def handle_call({:set_config, key, value}, _from, state) do
    case Configuration.set_config(key, value) do
      {:ok, _config} ->
        message = "Configuration '#{key}' set to '#{value}'"
        {:reply, {:ok, message}, state}

      {:error, changeset} ->
        error_message = format_changeset_errors(changeset)
        {:reply, {:error, error_message}, state}
    end
  end

  def handle_call({:list_configs}, _from, state) do
    configs = Configuration.list_configs()
    message = format_config_list(configs)
    {:reply, {:ok, message}, state}
  end

  def handle_call({:reset_config}, _from, state) do
    case Configuration.reset_config() do
      {:ok, message} ->
        {:reply, {:ok, message}, state}
    end
  end

  # AI Chat Callbacks

  def handle_call({:chat_with_ai, user_message}, _from, state) do
    # Store user message in history
    AgentHistory.add_conversation("user", user_message)

    # Get recent history for context
    recent_history = AgentHistory.get_recent_history(5)
    current_tasks = Tasks.list_tasks()

    # Build context for AI
    context = build_ai_context(recent_history, current_tasks)

    # Send to AI
    case AI.chat([%{role: "user", content: user_message}], context: context) do
      {:ok, ai_response} ->
        # Store AI response in history
        AgentHistory.add_conversation("assistant", ai_response)
        {:reply, {:ok, ai_response}, state}

      {:error, reason} ->
        {:reply, {:error, "AI service error: #{reason}"}, state}
    end
  end

  def handle_call({:test_ai_config}, _from, state) do
    case AI.test_configuration() do
      {:ok, message} ->
        {:reply, {:ok, message}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(_request, _from, state) do
    {:reply, {:ok, "Not implemented yet"}, state}
  end

  @impl true
  def handle_cast({:handle_checkin, checkin}, state) do
    Logger.info("Processing check-in: #{checkin.id}")

    # For now, just log the check-in
    # In future PRs, this will gather context and call the AI
    message = """
    🔔 Check-in Time!

    Scheduled for: #{format_datetime(checkin.scheduled_at)}
    #{if checkin.description, do: "Description: #{checkin.description}", else: ""}

    This is where the AI coach will provide insights and encouragement.
    (AI integration coming in future updates!)
    """

    # Display the message via the REPL
    # Note: In a real implementation, you'd want to send this to the user
    # For now, we'll just log it
    Logger.info(message)

    {:noreply, state}
  end

  # Private Functions

  defp format_task_list(tasks) do
    case tasks do
      [] ->
        "No tasks found. Add one with `/task add <description>`"

      _ ->
        tasks
        |> Enum.with_index(1)
        |> Enum.map(fn {task, index} ->
          status_emoji = get_status_emoji(task.status)
          "  #{index}. #{status_emoji} #{task.description} [#{task.status}]"
        end)
        |> Enum.join("\n")
        |> then(&"Your Tasks:\n#{&1}")
    end
  end

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

  defp create_task_backup do
    tasks = Tasks.list_tasks()
    filename = "task_backup_#{Date.utc_today()}.md"

    backup_content =
      tasks
      |> Enum.with_index(1)
      |> Enum.map(fn {task, _index} ->
        status_mark = if task.status == "COMPLETED", do: "x", else: " "
        "- [#{status_mark}] #{task.description} [#{task.status}]"
      end)
      |> Enum.join("\n")
      |> then(&"# Task Backup - #{Date.utc_today()}\n\n#{&1}")

    case File.write(filename, backup_content) do
      :ok -> {:ok, filename}
      {:error, reason} -> {:error, "Failed to write backup file: #{reason}"}
    end
  end

  defp format_config_list(configs) do
    case configs do
      [] ->
        "No configurations set. Use `/config set <key> <value>` to add some."

      _ ->
        configs
        |> Enum.map(fn {key, value} ->
          # Mask API keys for security
          display_value = if String.contains?(key, "api_key"), do: "***", else: value
          "  #{key}: #{display_value}"
        end)
        |> Enum.join("\n")
        |> then(&"Current Configurations:\n#{&1}")
    end
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map_join(", ", fn {_field, errors} ->
      Enum.join(errors, ", ")
    end)
  end

  defp build_ai_context(recent_history, current_tasks) do
    # Build a context string for the AI
    task_context =
      case current_tasks do
        [] ->
          "You have no tasks currently."

        tasks ->
          task_summary =
            tasks
            |> Enum.with_index(1)
            |> Enum.map(fn {task, index} ->
              "Task #{index}: #{task.description} [#{task.status}]"
            end)
            |> Enum.join("\n")

          "Your current tasks:\n#{task_summary}"
      end

    history_context =
      case recent_history do
        [] ->
          "This is your first interaction."

        history ->
          history_summary =
            history
            # Last 3 interactions
            |> Enum.take(3)
            |> Enum.map(fn entry ->
              "#{entry.role}: #{String.slice(entry.content, 0, 100)}#{if String.length(entry.content) > 100, do: "...", else: ""}"
            end)
            |> Enum.join("\n")

          "Recent conversation:\n#{history_summary}"
      end

    """
    You are OpenDevCoach, a personal developer productivity coach.
    You help developers stay organized, motivated, and productive.

    #{task_context}

    #{history_context}

    Be encouraging, practical, and helpful. Keep responses concise but supportive.
    """
  end

  defp format_datetime(datetime) do
    datetime
    |> DateTime.to_string()
    # Format as "YYYY-MM-DD HH:MM:SS"
    |> String.slice(0, 19)
  end
end
