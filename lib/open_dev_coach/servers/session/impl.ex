defmodule OpenDevCoach.Servers.Session.Impl do
  @moduledoc """
  Pure business logic for the Session functionality.

  This module contains all the application logic without any GenServer concerns.
  It can be easily tested and reused independently of the server implementation.
  """

  require Logger

  import OpenDevCoach.Helpers.Future
  import OpenDevCoach.Helpers.Persistence

  alias OpenDevCoach.AgentHistory
  alias OpenDevCoach.AgentHistory.Entry
  alias OpenDevCoach.AI
  alias OpenDevCoach.Configuration
  alias OpenDevCoach.Configuration.Config
  alias OpenDevCoach.Helpers.Changeset, as: ChangesetHelper
  alias OpenDevCoach.Notifier
  alias OpenDevCoach.Tasks
  alias OpenDevCoach.Tasks.Task, as: TaskSchema
  alias TioComodo.Repl.Server, as: ReplServer

  @type session_state() :: %{
          config: map(),
          history: [Entry.t()],
          self: atom(),
          tasks: [TaskSchema.t()]
        }

  @doc """
  Initializes the session state.
  """
  @spec init(_opts :: any()) :: session_state()
  def init(_opts) do
    Logger.info("OpenDevCoach Session started")
    config = Configuration.list_configs()
    history = AgentHistory.get_recent_history()
    tasks = Tasks.list_tasks()

    %{
      config: config,
      history: history,
      self: OpenDevCoach.Servers.Session,
      tasks: tasks
    }
  end

  # Task Management Functions

  @doc """
  Adds a new task to the system.
  """
  @spec add_task(map(), String.t()) :: {{:ok, list({Task.t(), integer()})}, map()}
  def add_task(state, description) do
    attrs = %{
      description: description,
      status: "PENDING",
      inserted_at: Timex.now()
    }

    {_task, new_state} =
      add_in_memory_and_persist_async(
        state,
        attrs,
        collection_key: :tasks,
        struct_module: TaskSchema,
        persist_function: &Tasks.create_task/1
      )

    list_tasks(new_state)
  end

  @doc """
  Lists all tasks in the system.
  """
  @spec list_tasks(map()) :: {{:ok, list({Task.t(), integer()})}, map()}
  def list_tasks(state) do
    tasks = sort_tasks_with_ordinal(state)
    {{:ok, tasks}, state}
  end

  @doc """
  Starts a task (marks as IN-PROGRESS) by task order number.
  """
  @spec start_task(session_state(), integer()) ::
          {{:ok, list({Task.t(), integer()})}, session_state()}
          | {{:error, String.t()}, session_state()}
  def start_task(state, task_ordinal) do
    case update_task_by_ordinal_in_state(state, task_ordinal, "IN-PROGRESS") do
      {:ok, new_state} ->
        if async_persistence?(),
          do: Task.start(fn -> Tasks.update_task_by_ordinal(task_ordinal, "IN-PROGRESS") end),
          else: Tasks.update_task_by_ordinal(task_ordinal, "IN-PROGRESS")

        {{:ok, tasks}, _} = list_tasks(new_state)
        {{:ok, tasks}, new_state}

      {:error, reason} ->
        Logger.error("Failed to start task: #{reason}")
        {{:error, reason}, state}
    end
  end

  defp update_task_by_ordinal_in_state(state, task_ordinal, status)
       when is_integer(task_ordinal) do
    sorted_tasks = sort_tasks_with_ordinal(state)

    if task_ordinal < 1 or task_ordinal > length(sorted_tasks) do
      {:error, "Task not found"}
    else
      {task, _ordinal} = Enum.at(sorted_tasks, task_ordinal - 1)

      new_tasks =
        state
        |> Map.get(:tasks, [])
        |> maybe_put_other_tasks_on_hold("IN-PROGRESS")
        |> Enum.map(fn t ->
          if task_matches?(t, task), do: %{task | status: status}, else: t
        end)

      {:ok, %{state | tasks: new_tasks}}
    end
  end

  defp update_task_by_ordinal_in_state(_, _, _) do
    Logger.error("Invalid task number")
    {:error, "Invalid task number"}
  end

  defp sort_tasks_with_ordinal(state) do
    state
    |> Map.get(:tasks, [])
    |> Enum.sort(&compare_tasks_desc/2)
    |> Enum.with_index()
    |> Enum.map(fn {task, index} ->
      {task, index + 1}
    end)
  end

  defp compare_tasks_desc(task1, task2) do
    case {task1.inserted_at, task2.inserted_at} do
      {nil, nil} -> false
      {nil, _} -> false
      {_, nil} -> true
      {dt1, dt2} -> DateTime.compare(dt1, dt2) == :gt
    end
  end

  defp task_matches?(task1, task2) do
    # Match by ID if both have IDs, otherwise match by description (for tests)
    cond do
      task1.id != nil and task2.id != nil -> task1.id == task2.id
      task1.description == task2.description -> true
      true -> false
    end
  end

  defp maybe_put_other_tasks_on_hold(tasks, "IN-PROGRESS") do
    Enum.map(tasks, fn task ->
      if task.status == "IN-PROGRESS", do: %{task | status: "ON-HOLD"}, else: task
    end)
  end

  defp maybe_put_other_tasks_on_hold(tasks, _status), do: tasks

  @doc """
  Completes a task (marks as COMPLETED) by task order number.
  """
  @spec complete_task(session_state(), integer()) :: {String.t(), session_state()}
  def complete_task(state, task_ordinal) do
    case update_task_by_ordinal_in_state(state, task_ordinal, "COMPLETED") do
      {:ok, new_state} ->
        if async_persistence?(),
          do: Task.start(fn -> Tasks.update_task_by_ordinal(task_ordinal, "COMPLETED") end),
          else: Tasks.update_task_by_ordinal(task_ordinal, "COMPLETED")

        new_state

      {:error, reason} ->
        Logger.error("Failed to complete task: #{reason}")
        state
    end
  end

  @doc """
  Removes a task from the system by task order number.
  """
  def remove_task(state, task_ordinal) do
    case remove_task_by_ordinal_in_state(state, task_ordinal) do
      {:ok, new_state} ->
        if async_persistence?(),
          do: Task.start(fn -> Tasks.remove_task_by_ordinal(task_ordinal) end),
          else: Tasks.remove_task_by_ordinal(task_ordinal)

        new_state

      {:error, reason} ->
        Logger.error("Failed to remove task: #{reason}")
        state
    end
  end

  defp remove_task_by_ordinal_in_state(state, task_ordinal) when is_integer(task_ordinal) do
    sorted_tasks = sort_tasks_with_ordinal(state)

    if task_ordinal < 1 or task_ordinal > length(sorted_tasks) do
      {:error, "Task not found"}
    else
      {task, _ordinal} = Enum.at(sorted_tasks, task_ordinal - 1)

      new_tasks =
        state
        |> Map.get(:tasks, [])
        |> Enum.reject(&task_matches?(&1, task))

      {:ok, %{state | tasks: new_tasks}}
    end
  end

  defp remove_task_by_ordinal_in_state(_, _) do
    {:error, "Invalid task ordinal"}
  end

  @doc """
  Creates a backup of all tasks in markdown format.
  """
  def backup_tasks(state, file_write_fn \\ &File.write/2) do
    case create_task_backup(state, file_write_fn) do
      {:ok, filename} ->
        message = "Tasks backed up to #{filename}"
        {{:ok, message}, state}

      {:error, reason} ->
        {{:error, "Failed to backup tasks: #{reason}"}, state}
    end
  end

  # Configuration Management Functions

  @doc """
  Gets a configuration value by key.
  """
  @spec get_config(session_state(), String.t()) ::
          {{:ok, {String.t(), any()}} | {:error, String.t()}, session_state()}
  def get_config(state, key) do
    case Map.get(state.config, key, nil) do
      nil ->
        {{:error, key}, state}

      value ->
        {{:ok, {key, value}}, state}
    end
  end

  @doc """
  Sets a configuration key-value pair.
  """
  def set_config(state, key, value) do
    case set_config_in_state(state, key, value) do
      {:ok, new_state} ->
        if async_persistence?(),
          do: Task.start(fn -> Configuration.set_config(key, value) end),
          else: Configuration.set_config(key, value)

        message = "Configuration '#{key}' set to '#{value}'"
        {{:ok, message}, new_state}

      {:error, error_message} ->
        {{:error, error_message}, state}
    end
  end

  defp set_config_in_state(state, key, value) do
    # Create a temporary config struct for validation
    temp_config = %Config{}
    changeset = Config.changeset(temp_config, %{key: key, value: value})

    if changeset.valid? do
      {:ok, %{state | config: Map.put(state.config, key, value)}}
    else
      error_message = ChangesetHelper.format_changeset_errors(changeset)
      {:error, error_message}
    end
  end

  @doc """
  Lists all configuration settings.
  """
  @spec list_configs(session_state()) :: {{:ok, map()}, session_state()}
  def list_configs(state) do
    {{:ok, state.config}, state}
  end

  @doc """
  Resets all configuration to defaults.
  """
  def reset_config(state) do
    config = %{}

    if async_persistence?(),
      do: Task.start(fn -> Configuration.reset_config() end),
      else: Configuration.reset_config()

    {{:ok, "All configurations have been reset"}, %{state | config: config}}
  end

  # AI Chat Functions

  @doc """
  Sends a message to the AI and manages conversation history.
  """
  def chat_with_ai(state, user_message) do
    state = add_history(state, "user", user_message)

    # Get recent history for context
    recent_history = get_history(state, 8)
    current_tasks = Tasks.list_tasks()

    # Build context for AI
    context = build_ai_context(recent_history, current_tasks)

    # Send to AI
    case AI.chat([%{role: "user", content: user_message}], context: context) do
      {:ok, %{text: ai_response_text}} ->
        # Store AI response in history
        AgentHistory.add_conversation("assistant", ai_response_text)
        {{:ok, ai_response_text}, state}

      {:error, reason} ->
        {{:error, "AI service error: #{reason}"}, state}
    end
  end

  defp add_history(state, role, content) do
    new_history = state.history ++ [%Entry{role: role, content: content}]

    if async_persistence?(),
      do: Task.start(fn -> AgentHistory.add_conversation(role, content) end),
      else: AgentHistory.add_conversation(role, content)

    %{state | history: new_history}
  end

  defp get_history(state, limit) do
    Enum.slice(state.history, -limit..-1)
  end

  @doc """
  Tests the AI configuration by sending a simple message.
  """
  def test_ai_config(state) do
    case AI.test_configuration(state.config) do
      {:ok, message} ->
        {{:ok, message}, state}

      {:error, reason} ->
        {{:error, reason}, state}
    end
  end

  @doc """
  Handles a check-in trigger from the scheduler.
  """
  def handle_checkin(state, checkin) do
    Logger.info("Processing check-in: #{checkin.id}")

    recent_history = AgentHistory.get_recent_history(5)
    current_tasks = Tasks.list_tasks()

    context = build_ai_context(recent_history, current_tasks)

    checkin_prompt = """
    It's check-in time! Here's what's happening:

    #{if checkin.description, do: "Check-in: #{checkin.description}", else: "Regular check-in"}

    Please provide encouragement, insights, and help the user stay productive.
    Keep your response focused and actionable.
    """

    process_checkin_with_ai(checkin, checkin_prompt, context)

    {{:ok, "Check-in processed"}, state}
  end

  @doc """
  Send console output.
  """
  @spec output(atom(), String.t()) :: :ok
  def output(_level, message) do
    future(:output, "add colour coding for levels")
    ReplServer.output(message)
  end

  defp create_task_backup(state, file_write_fn) do
    tasks = Map.get(state, :tasks, [])
    filename = "task_backup_#{Date.utc_today()}.md"

    backup_content =
      tasks
      |> Enum.with_index(1)
      |> Enum.map_join("\n", fn {task, _index} ->
        status_mark = if task.status == "COMPLETED", do: "x", else: " "
        "- [#{status_mark}] #{task.description} [#{task.status}]"
      end)
      |> then(&"# Task Backup - #{Date.utc_today()}\n\n#{&1}")

    case file_write_fn.(filename, backup_content) do
      :ok -> {:ok, filename}
      {:error, reason} -> {:error, "Failed to write backup file: #{reason}"}
    end
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
            |> Enum.map_join("\n", fn {task, index} ->
              "Task #{index}: #{task.description} [#{task.status}]"
            end)

          "Your current tasks:\n#{task_summary}"
      end

    history_context =
      case recent_history do
        [] ->
          "This is your first interaction."

        history ->
          # credo:disable-for-lines:7 Credo.Check.Refactor.Nesting
          history_summary =
            history
            # Last 3 interactions
            |> Enum.take(3)
            |> Enum.map_join("\n", fn entry ->
              "#{entry.role}: #{String.slice(entry.content, 0, 100)}#{if String.length(entry.content) > 100, do: "...", else: ""}"
            end)

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
    # Convert UTC to local timezone for display
    local_time =
      case datetime do
        %DateTime{} ->
          timezone = Application.get_env(:open_dev_coach, :timezone, "America/New_York")
          DateTime.shift_zone!(datetime, timezone)

        _ ->
          datetime
      end

    local_time
    |> DateTime.to_string()
    # Format as "YYYY-MM-DD HH:MM:SS"
    |> String.slice(0, 19)
  end

  # Private function to handle AI interaction for check-ins
  defp process_checkin_with_ai(checkin, prompt, context) do
    case AI.chat([%{role: "user", content: prompt}], context: context) do
      {:ok, %{text: ai_response_text}} ->
        handle_successful_ai_response(checkin, ai_response_text)

      {:error, reason} ->
        handle_ai_error(checkin, reason)
    end
  end

  defp handle_successful_ai_response(checkin, ai_response_text) do
    # Store the check-in interaction in history
    AgentHistory.add_conversation(
      "system",
      "Check-in triggered: #{if checkin.description, do: checkin.description, else: "Regular check-in"}"
    )

    AgentHistory.add_conversation("assistant", ai_response_text)

    # Display the message via the REPL
    message = """
    🔔 Check-in Time!

    Scheduled for: #{format_datetime(checkin.scheduled_at)}
    #{if checkin.description, do: "Description: #{checkin.description}", else: ""}

    🤖 AI Coach Response:
    #{ai_response_text}
    """

    # Log the message and send desktop notification
    Logger.info(message)

    # Send desktop notification
    notification_title = "OpenDevCoach Check-in"

    notification_message =
      if checkin.description do
        "#{checkin.description}: #{String.slice(ai_response_text, 0, 100)}#{if String.length(ai_response_text) > 100, do: "...", else: ""}"
      else
        "Time for your check-in! #{String.slice(ai_response_text, 0, 100)}#{if String.length(ai_response_text) > 100, do: "...", else: ""}"
      end

    Notifier.notify(notification_title, notification_message)
  end

  defp handle_ai_error(checkin, reason) do
    Logger.error("AI service error during check-in: #{reason}")

    # Fallback message if AI fails
    message = """
    🔔 Check-in Time!

    Scheduled for: #{format_datetime(checkin.scheduled_at)}
    #{if checkin.description, do: "Description: #{checkin.description}", else: ""}

    ⚠️ AI service temporarily unavailable.
    This is a good time to review your tasks and progress!
    """

    Logger.info(message)

    # Send fallback desktop notification
    notification_title = "OpenDevCoach Check-in"

    notification_message =
      if checkin.description do
        "#{checkin.description}: Time to review your tasks and progress!"
      else
        "Check-in time! Review your tasks and progress."
      end

    Notifier.notify(notification_title, notification_message)
  end
end
