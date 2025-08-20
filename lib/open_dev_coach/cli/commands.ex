defmodule OpenDevCoach.CLI.Commands do
  @moduledoc """
  Command handler for the OpenDevCoach REPL.

  This module provides the command interface for tio_comodo,
  handling basic commands and routing non-commands to the AI system.
  """

  alias OpenDevCoach.Session

  @doc """
  Returns the map of available commands for the REPL.
  """
  def commands do
    %{
      "help" => {__MODULE__, :help, []},
      "quit" => {__MODULE__, :quit, []},
      "task" => {__MODULE__, :task_dispatch, []},
      "catchall_handler" => {__MODULE__, :handle_unknown, []}
    }
  end

  @doc """
  Displays help information for available commands.
  """
  def help(_args) do
    help_text = """
    OpenDevCoach - Your Personal Developer Coach

    Available Commands:
      /help          - Show this help message
      /quit          - Exit the application

    Task Management:
      /task add <description>     - Add a new task
      /task list                  - List all tasks
      /task start <number>        - Start working on a task
      /task complete <number>     - Mark a task as completed
      /task remove <number>       - Remove a task
      /task backup                - Create backup of all tasks

    Any other input will be sent to your AI coach for assistance.
    """

    {:ok, help_text}
  end

  @doc """
  Exits the application cleanly.
  """
  def quit(_args) do
    {:stop, :normal, "Goodbye! Keep coding and stay productive! 👨‍💻"}
  end

  @doc """
  Dispatches task-related commands based on the first argument.
  """
  def task_dispatch(args) do
    case args do
      ["add" | description_parts] ->
        description = Enum.join(description_parts, " ")
        task_add(description)

      ["list"] ->
        task_list([])

      ["start", task_number] ->
        task_start(task_number)

      ["complete", task_number] ->
        task_complete(task_number)

      ["remove", task_number] ->
        task_remove(task_number)

      ["backup"] ->
        task_backup([])

      _ ->
        {:error, "Invalid task command. Use: add, list, start, complete, remove, or backup"}
    end
  end

  @doc """
  Adds a new task with the given description.
  """
  def task_add(description) when byte_size(description) > 0 do
    case Session.add_task(description) do
      {:ok, message} -> {:ok, message}
      {:error, message} -> {:error, message}
    end
  end

  def task_add(_), do: {:error, "Task description cannot be empty"}

  @doc """
  Lists all tasks in the system.
  """
  def task_list(_args) do
    case Session.list_tasks() do
      {:ok, message} -> {:ok, message}
      {:error, message} -> {:error, message}
    end
  end

  @doc """
  Starts a task by its display number.
  """
  def task_start(task_number) do
    case parse_task_number(task_number) do
      {:ok, task_id} ->
        case Session.start_task(task_id) do
          {:ok, message} -> {:ok, message}
          {:error, message} -> {:error, message}
        end

      {:error, message} ->
        {:error, message}
    end
  end

  @doc """
  Completes a task by its display number.
  """
  def task_complete(task_number) do
    case parse_task_number(task_number) do
      {:ok, task_id} ->
        case Session.complete_task(task_id) do
          {:ok, message} -> {:ok, message}
          {:error, message} -> {:error, message}
        end

      {:error, message} ->
        {:error, message}
    end
  end

  @doc """
  Removes a task by its display number.
  """
  def task_remove(task_number) do
    case parse_task_number(task_number) do
      {:ok, task_id} ->
        case Session.remove_task(task_id) do
          {:ok, message} -> {:ok, message}
          {:error, message} -> {:error, message}
        end

      {:error, message} ->
        {:error, message}
    end
  end

  @doc """
  Creates a backup of all tasks in markdown format.
  """
  def task_backup(_args) do
    case Session.backup_tasks() do
      {:ok, message} -> {:ok, message}
      {:error, message} -> {:error, message}
    end
  end

  @doc """
  Handles any input that doesn't match a defined command.

  For now, this echoes back the input. In future PRs, this will
  route to the AI system for coaching and assistance.
  """
  def handle_unknown(input) do
    {:ok, "You said: #{input}\n\nThis will be sent to your AI coach in future updates!"}
  end

  # Private Functions

  defp parse_task_number(task_number) do
    case Integer.parse(task_number) do
      {number, ""} when number > 0 ->
        # Convert display number to actual task ID by listing tasks and finding the right one
        case Session.list_tasks() do
          {:ok, _message} ->
            # For now, we'll use the display number as the task ID
            # In a more sophisticated implementation, we'd map display numbers to actual IDs
            {:ok, number}

          {:error, message} ->
            {:error, "Failed to list tasks: #{message}"}
        end

      _ ->
        {:error, "Invalid task number. Please provide a positive integer."}
    end
  end
end
