defmodule OpenDevCoach.Tasks do
  @moduledoc """
  Context module for managing tasks in the OpenDevCoach application.

  Provides functions for creating, reading, updating, and deleting tasks,
  with special handling for task status transitions.
  """

  import Ecto.Query
  alias OpenDevCoach.Repo
  alias OpenDevCoach.Tasks.Task

  @doc """
  Lists all tasks ordered by creation time (newest first).
  """
  def list_tasks do
    Task
    |> order_by([t], desc: t.inserted_at)
    |> Repo.all()
  end

  @doc """
  Creates a new task with the given description.
  Default status is "PENDING".
  """
  def add_task(description) when is_binary(description) and byte_size(description) > 0 do
    %Task{}
    |> Task.changeset(%{description: description})
    |> Repo.insert()
  end

  def add_task(_), do: {:error, "Task description cannot be empty"}

  @doc """
  Retrieves a task by its ID.
  """
  def get_task(id) when is_integer(id) do
    case Repo.get(Task, id) do
      nil -> {:error, "Task not found"}
      task -> {:ok, task}
    end
  end

  def get_task(_), do: {:error, "Invalid task ID"}

  @doc """
  Updates the status of a task. When setting status to "IN-PROGRESS",
  automatically puts all other IN-PROGRESS tasks on hold.
  """
  def update_task_status(task_id, new_status) when is_integer(task_id) do
    Repo.transaction(fn ->
      # If setting to IN-PROGRESS, put other tasks on hold
      if new_status == "IN-PROGRESS" do
        from(t in Task, where: t.status == "IN-PROGRESS")
        |> Repo.update_all(set: [status: "ON-HOLD"])
      end

      # Update the target task
      case Repo.get(Task, task_id) do
        nil ->
          Repo.rollback("Task not found")

        task ->
          changes =
            %{status: new_status}
            |> maybe_add_timestamp()

          task
          |> Task.changeset(changes)
          |> Repo.update()
      end
    end)
  end

  def update_task_status(_, _), do: {:error, "Invalid parameters"}

  defp maybe_add_timestamp(%{status: "IN-PROGRESS"} = changes),
    do: Map.put(changes, :started_at, DateTime.utc_now())

  defp maybe_add_timestamp(%{status: "COMPLETED"} = changes),
    do: Map.put(changes, :completed_at, DateTime.utc_now())

  defp maybe_add_timestamp(changes), do: changes

  @doc """
  Removes a task by its ID.
  """
  def remove_task(id) when is_integer(id) do
    case Repo.get(Task, id) do
      nil -> {:error, "Task not found"}
      task -> Repo.delete(task)
    end
  end

  def remove_task(_), do: {:error, "Invalid task ID"}
end
