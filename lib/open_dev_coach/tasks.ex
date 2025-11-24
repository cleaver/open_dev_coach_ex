defmodule OpenDevCoach.Tasks do
  @moduledoc """
  Context module for managing tasks in the OpenDevCoach application.

  Provides functions for creating, reading, updating, and deleting tasks,
  with special handling for task status transitions.
  """

  import Ecto.Query
  alias OpenDevCoach.Helpers.Date, as: DateHelper
  alias OpenDevCoach.Repo
  alias OpenDevCoach.Tasks.Task

  @doc """
  Prepares an update changeset, handling timezone conversion.
  """
  def prepare_update_changeset(%Task{} = task, attrs) do
    attrs = convert_local_to_utc(attrs)
    Task.changeset(task, attrs)
  end

  @doc """
  Applies a valid changeset and returns the new struct in local time.
  Use this for in-memory state updates.
  """
  def apply_update_changeset(%Ecto.Changeset{valid?: true} = changeset) do
    new_struct_utc = Ecto.Changeset.apply_action!(changeset, :update)
    convert_utc_to_local(new_struct_utc)
  end

  def apply_update_changeset(%Ecto.Changeset{} = changeset), do: {:error, changeset}

  @doc """
  Persists a changeset to the database.
  This is the "persistence" step for an async Task.
  """
  def persist_update_changeset(%Ecto.Changeset{} = changeset) do
    Repo.update(changeset)
  end

  @doc """
  Creates a new task, converting local time to UTC for storage.
  """
  def create_task(attrs \\ %{}) do
    attrs =
      attrs
      |> maybe_generate_id()
      |> convert_local_to_utc()

    Task.changeset(%Task{}, attrs)
    |> Repo.insert()
    |> case do
      {:ok, task} -> {:ok, convert_utc_to_local(task)}
      error -> error
    end
  end

  defp maybe_generate_id(attrs) do
    if Map.has_key?(attrs, :id) or Map.has_key?(attrs, "id") do
      attrs
    else
      Map.put(attrs, :id, Ecto.UUID.generate())
    end
  end

  @doc """
  Lists all tasks ordered by creation time (newest first).
  """
  @spec list_tasks() :: [Task.t()]
  def list_tasks do
    Task
    |> order_by([t], desc: t.inserted_at)
    |> Repo.all()
    |> Enum.map(&convert_utc_to_local/1)
  end

  @doc """
  Retrieves a task by its ID.
  """
  def get_task(id) when is_binary(id) do
    case Repo.get(Task, id) do
      nil -> {:error, "Task not found"}
      task -> {:ok, convert_utc_to_local(task)}
    end
  end

  def get_task(_), do: {:error, "Invalid task ID"}

  @doc """
  Updates a task by its ordinal number.
  """
  @spec update_task_by_ordinal(integer(), String.t()) :: {:ok, Task.t()} | {:error, String.t()}
  def update_task_by_ordinal(ordinal, status) when is_integer(ordinal) do
    task =
      list_tasks()
      |> Enum.at(ordinal - 1)

    case task do
      nil -> {:error, "Task not found"}
      task -> update_task_status(task.id, status)
    end
  end

  @doc """
  Updates the status of a task. When setting status to "IN-PROGRESS",
  automatically puts all other IN-PROGRESS tasks on hold.
  """
  def update_task_status(task_id, new_status) when is_binary(task_id) do
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
          |> case do
            {:ok, updated_task} -> convert_utc_to_local(updated_task)
            error -> Repo.rollback(error)
          end
      end
    end)
    |> case do
      {:ok, task} -> {:ok, task}
      error -> error
    end
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
  @spec remove_task(binary()) :: {:ok, Task.t()} | {:error, String.t()}
  def remove_task(id) when is_binary(id) do
    case Repo.get(Task, id) do
      nil ->
        {:error, "Task not found"}

      task ->
        Repo.delete(task)
        |> case do
          {:ok, deleted_task} -> {:ok, convert_utc_to_local(deleted_task)}
          error -> error
        end
    end
  end

  def remove_task(_), do: {:error, "Invalid task ID"}

  @doc """
  Removes a task by its ordinal number.
  """
  @spec remove_task_by_ordinal(integer()) :: {:ok, Task.t()} | {:error, String.t()}
  def remove_task_by_ordinal(ordinal) when is_integer(ordinal) do
    task =
      list_tasks()
      |> Enum.at(ordinal - 1)

    case task do
      nil ->
        {:error, "Task not found"}

      task ->
        Repo.delete(task)
        |> case do
          {:ok, deleted_task} -> {:ok, convert_utc_to_local(deleted_task)}
          error -> error
        end
    end
  end

  def remove_task_by_ordinal(_), do: {:error, "Invalid task ordinal"}

  # Private timezone conversion functions

  @doc false
  defp convert_local_to_utc(attrs) when is_map(attrs) do
    attrs
    |> maybe_convert_datetime(:started_at)
    |> maybe_convert_datetime(:completed_at)
    |> maybe_convert_datetime("started_at")
    |> maybe_convert_datetime("completed_at")
  end

  defp convert_local_to_utc(attrs), do: attrs

  defp maybe_convert_datetime(attrs, key) do
    case Map.get(attrs, key) do
      nil ->
        attrs

      local_time when not is_nil(local_time) ->
        utc_time =
          case local_time do
            %NaiveDateTime{} ->
              # Assume local time, convert to UTC
              local_time
              |> Timex.to_datetime(DateHelper.local_timezone())
              |> Timex.Timezone.convert("Etc/UTC")

            %DateTime{} ->
              # Already a DateTime, ensure it's UTC
              Timex.Timezone.convert(local_time, "Etc/UTC")

            _ ->
              local_time
          end

        Map.put(attrs, key, utc_time)
    end
  end

  @doc false
  defp convert_utc_to_local(%Task{} = task) do
    %{
      task
      | started_at: convert_datetime_to_local(task.started_at),
        completed_at: convert_datetime_to_local(task.completed_at)
    }
  end

  @doc false
  defp convert_datetime_to_local(nil), do: nil

  defp convert_datetime_to_local(utc_datetime) do
    utc_datetime
    |> Timex.Timezone.convert(DateHelper.local_timezone())
  end
end
