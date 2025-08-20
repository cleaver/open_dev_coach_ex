defmodule OpenDevCoach.CLI.TaskCommands do
  @moduledoc """
  Task management commands for the OpenDevCoach REPL.

  This module handles all task-related CLI operations including
  adding, listing, starting, completing, removing, and backing up tasks.
  """

  alias OpenDevCoach.Session

  @doc """
  Dispatches task-related commands based on the first argument.
  """
  def dispatch(args) do
    case args do
      ["add" | description_parts] ->
        description = Enum.join(description_parts, " ")
        add(description)

      ["list"] ->
        list([])

      ["start", task_number] ->
        start(task_number)

      ["complete", task_number] ->
        complete(task_number)

      ["remove", task_number] ->
        remove(task_number)

      ["backup"] ->
        backup([])

      _ ->
        {:error, "Invalid task command. Use: add, list, start, complete, remove, or backup"}
    end
  end

  @doc """
  Adds a new task with the given description.
  """
  def add(description) when byte_size(description) > 0 do
    case Session.add_task(description) do
      {:ok, message} -> {:ok, message}
      {:error, message} -> {:error, message}
    end
  end

  def add(_), do: {:error, "Task description cannot be empty"}

  @doc """
  Lists all tasks in the system.
  """
  def list(_args) do
    case Session.list_tasks() do
      {:ok, message} -> {:ok, message}
      {:error, message} -> {:error, message}
    end
  end

  @doc """
  Starts a task by its display number.
  """
  def start(task_number) do
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
  def complete(task_number) do
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
  def remove(task_number) do
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
  def backup(_args) do
    case Session.backup_tasks() do
      {:ok, message} -> {:ok, message}
      {:error, message} -> {:error, message}
    end
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
