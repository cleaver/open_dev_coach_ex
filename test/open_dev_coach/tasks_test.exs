defmodule OpenDevCoach.TasksTest do
  use OpenDevCoach.DataCase, async: false

  alias OpenDevCoach.Tasks

  setup do
    # Set a fixed timezone for testing
    Application.put_env(:open_dev_coach, :timezone, "America/New_York")
    :ok
  end

  describe "create_task/1" do
    test "creates a task with required fields" do
      attrs = %{
        description: "Test task",
        status: "PENDING"
      }

      assert {:ok, task} = Tasks.create_task(attrs)
      assert task.description == "Test task"
      assert task.status == "PENDING"
      assert is_binary(task.id)
    end

    test "generates UUID if id not provided" do
      attrs = %{
        description: "Test task",
        status: "PENDING"
      }

      assert {:ok, task} = Tasks.create_task(attrs)
      assert is_binary(task.id)
      assert String.length(task.id) > 0
    end

    test "uses provided id if present" do
      provided_id = Ecto.UUID.generate()

      attrs = %{
        id: provided_id,
        description: "Test task",
        status: "PENDING"
      }

      assert {:ok, task} = Tasks.create_task(attrs)
      assert task.id == provided_id
    end

    test "uses provided id as string if present" do
      provided_id = Ecto.UUID.generate()

      attrs = %{
        "id" => provided_id,
        "description" => "Test task",
        "status" => "PENDING"
      }

      assert {:ok, task} = Tasks.create_task(attrs)
      assert task.id == provided_id
    end

    test "converts local time to UTC for started_at" do
      local_time = ~N[2025-01-15 14:30:00]

      attrs = %{
        description: "Test task",
        status: "IN-PROGRESS",
        started_at: local_time
      }

      assert {:ok, task} = Tasks.create_task(attrs)
      assert task.started_at != nil
      # The returned task should be in local timezone
      assert task.started_at.time_zone == "America/New_York"
    end

    test "converts local time to UTC for completed_at" do
      local_time = ~N[2025-01-15 16:30:00]

      attrs = %{
        description: "Test task",
        status: "COMPLETED",
        completed_at: local_time
      }

      assert {:ok, task} = Tasks.create_task(attrs)
      assert task.completed_at != nil
      # The returned task should be in local timezone
      assert task.completed_at.time_zone == "America/New_York"
    end

    test "returns error for invalid attributes" do
      attrs = %{
        description: "",
        status: "PENDING"
      }

      assert {:error, changeset} = Tasks.create_task(attrs)
      refute changeset.valid?
    end

    test "returns error for invalid status" do
      attrs = %{
        description: "Test task",
        status: "INVALID-STATUS"
      }

      assert {:error, changeset} = Tasks.create_task(attrs)
      refute changeset.valid?
    end

    test "returns error for description too long" do
      long_description = String.duplicate("a", 1001)

      attrs = %{
        description: long_description,
        status: "PENDING"
      }

      assert {:error, changeset} = Tasks.create_task(attrs)
      refute changeset.valid?
    end
  end

  describe "list_tasks/0" do
    test "returns empty list when no tasks exist" do
      assert Tasks.list_tasks() == []
    end

    test "returns tasks ordered by creation time (newest first)" do
      time_now = Timex.now()
      time_past = Timex.shift(time_now, seconds: -1)

      {:ok, _task1} =
        Tasks.create_task(%{description: "First task", status: "PENDING", inserted_at: time_past})

      {:ok, _task2} =
        Tasks.create_task(%{description: "Second task", status: "PENDING", inserted_at: time_now})

      [task1, task2] = tasks = Tasks.list_tasks()
      assert length(tasks) == 2
      assert task1.description == "Second task"
      assert task2.description == "First task"
    end

    test "converts UTC times to local timezone" do
      {:ok, _task} =
        Tasks.create_task(%{
          description: "Test task",
          status: "IN-PROGRESS",
          started_at: ~N[2025-01-15 14:30:00]
        })

      [task] = Tasks.list_tasks()
      assert task.started_at != nil
      assert task.started_at.time_zone == "America/New_York"
    end
  end

  describe "get_task/1" do
    test "returns task when found" do
      {:ok, created_task} =
        Tasks.create_task(%{
          description: "Test task",
          status: "PENDING"
        })

      assert {:ok, task} = Tasks.get_task(created_task.id)
      assert task.id == created_task.id
      assert task.description == "Test task"
    end

    test "returns error when task not found" do
      non_existent_id = Ecto.UUID.generate()
      assert {:error, "Task not found"} = Tasks.get_task(non_existent_id)
    end

    test "returns error for invalid id type" do
      assert {:error, "Invalid task ID"} = Tasks.get_task(123)
      assert {:error, "Invalid task ID"} = Tasks.get_task(nil)
    end

    test "converts UTC times to local timezone" do
      {:ok, created_task} =
        Tasks.create_task(%{
          description: "Test task",
          status: "IN-PROGRESS",
          started_at: ~N[2025-01-15 14:30:00]
        })

      assert {:ok, task} = Tasks.get_task(created_task.id)
      assert task.started_at != nil
      assert task.started_at.time_zone == "America/New_York"
    end
  end

  describe "update_task_by_ordinal/2" do
    test "updates task by ordinal number" do
      time_now = Timex.now()
      time_past = Timex.shift(time_now, seconds: -1)

      {:ok, _task1} =
        Tasks.create_task(%{description: "First task", status: "PENDING", inserted_at: time_past})

      {:ok, task2} =
        Tasks.create_task(%{description: "Second task", status: "PENDING", inserted_at: time_now})

      assert {:ok, updated_task} = Tasks.update_task_by_ordinal(1, "IN-PROGRESS")
      assert updated_task.id == task2.id
      assert updated_task.status == "IN-PROGRESS"
    end

    test "returns error for invalid ordinal" do
      assert {:error, "Task not found"} = Tasks.update_task_by_ordinal(1, "IN-PROGRESS")
      assert {:error, "Task not found"} = Tasks.update_task_by_ordinal(0, "IN-PROGRESS")
      assert {:error, "Task not found"} = Tasks.update_task_by_ordinal(-1, "IN-PROGRESS")
    end
  end

  describe "update_task_status/2" do
    test "updates task status" do
      {:ok, task} = Tasks.create_task(%{description: "Test task", status: "PENDING"})

      assert {:ok, updated_task} = Tasks.update_task_status(task.id, "IN-PROGRESS")
      assert updated_task.status == "IN-PROGRESS"
    end

    test "sets started_at when status changes to IN-PROGRESS" do
      {:ok, task} = Tasks.create_task(%{description: "Test task", status: "PENDING"})

      assert {:ok, updated_task} = Tasks.update_task_status(task.id, "IN-PROGRESS")
      assert updated_task.status == "IN-PROGRESS"
      assert updated_task.started_at != nil
      assert updated_task.started_at.time_zone == "America/New_York"
    end

    test "sets completed_at when status changes to COMPLETED" do
      {:ok, task} = Tasks.create_task(%{description: "Test task", status: "PENDING"})

      assert {:ok, updated_task} = Tasks.update_task_status(task.id, "COMPLETED")
      assert updated_task.status == "COMPLETED"
      assert updated_task.completed_at != nil
      assert updated_task.completed_at.time_zone == "America/New_York"
    end

    test "puts other IN-PROGRESS tasks on hold when setting to IN-PROGRESS" do
      {:ok, task1} = Tasks.create_task(%{description: "Task 1", status: "IN-PROGRESS"})
      {:ok, task2} = Tasks.create_task(%{description: "Task 2", status: "PENDING"})

      assert {:ok, _updated_task} = Tasks.update_task_status(task2.id, "IN-PROGRESS")

      assert {:ok, updated_task1} = Tasks.get_task(task1.id)
      assert updated_task1.status == "ON-HOLD"

      assert {:ok, updated_task2} = Tasks.get_task(task2.id)
      assert updated_task2.status == "IN-PROGRESS"
    end

    test "returns error when task not found" do
      non_existent_id = Ecto.UUID.generate()
      assert {:error, "Task not found"} = Tasks.update_task_status(non_existent_id, "IN-PROGRESS")
    end

    test "returns error for invalid parameters" do
      assert {:error, "Invalid parameters"} = Tasks.update_task_status(123, "IN-PROGRESS")
      assert {:error, "Invalid parameters"} = Tasks.update_task_status(nil, "IN-PROGRESS")
    end
  end

  describe "remove_task/1" do
    test "removes task by id" do
      {:ok, task} = Tasks.create_task(%{description: "Test task", status: "PENDING"})

      assert {:ok, deleted_task} = Tasks.remove_task(task.id)
      assert deleted_task.id == task.id

      assert {:error, "Task not found"} = Tasks.get_task(task.id)
    end

    test "returns error when task not found" do
      non_existent_id = Ecto.UUID.generate()
      assert {:error, "Task not found"} = Tasks.remove_task(non_existent_id)
    end

    test "returns error for invalid id type" do
      assert {:error, "Invalid task ID"} = Tasks.remove_task(123)
      assert {:error, "Invalid task ID"} = Tasks.remove_task(nil)
    end

    test "returns task in local timezone" do
      {:ok, task} =
        Tasks.create_task(%{
          description: "Test task",
          status: "IN-PROGRESS",
          started_at: ~N[2025-01-15 14:30:00]
        })

      assert {:ok, deleted_task} = Tasks.remove_task(task.id)
      assert deleted_task.started_at != nil
      assert deleted_task.started_at.time_zone == "America/New_York"
    end
  end

  describe "remove_task_by_ordinal/1" do
    test "removes task by ordinal number" do
      time_now = Timex.now()
      time_past = Timex.shift(time_now, seconds: -1)

      {:ok, _task1} =
        Tasks.create_task(%{description: "First task", status: "PENDING", inserted_at: time_past})

      {:ok, task2} =
        Tasks.create_task(%{description: "Second task", status: "PENDING", inserted_at: time_now})

      assert {:ok, deleted_task} = Tasks.remove_task_by_ordinal(1)
      assert deleted_task.id == task2.id

      tasks = Tasks.list_tasks()
      assert length(tasks) == 1
      assert hd(tasks).description == "First task"
    end

    test "returns error for invalid ordinal" do
      assert {:error, "Task not found"} = Tasks.remove_task_by_ordinal(1)
      assert {:error, "Task not found"} = Tasks.remove_task_by_ordinal(0)
      assert {:error, "Task not found"} = Tasks.remove_task_by_ordinal(-1)
    end

    test "returns error for invalid ordinal type" do
      assert {:error, "Invalid task ordinal"} = Tasks.remove_task_by_ordinal("1")
      assert {:error, "Invalid task ordinal"} = Tasks.remove_task_by_ordinal(nil)
    end
  end

  describe "prepare_update_changeset/2" do
    test "prepares changeset with timezone conversion" do
      {:ok, task} = Tasks.create_task(%{description: "Test task", status: "PENDING"})

      local_time = ~N[2025-01-15 14:30:00]
      attrs = %{started_at: local_time}

      changeset = Tasks.prepare_update_changeset(task, attrs)
      assert changeset.valid?
      assert changeset.changes.started_at != nil
    end

    test "returns invalid changeset for invalid attributes" do
      {:ok, task} = Tasks.create_task(%{description: "Test task", status: "PENDING"})

      attrs = %{description: ""}

      changeset = Tasks.prepare_update_changeset(task, attrs)
      refute changeset.valid?
    end
  end

  describe "apply_update_changeset/1" do
    test "applies valid changeset and returns task in local time" do
      {:ok, task} = Tasks.create_task(%{description: "Test task", status: "PENDING"})

      changeset = Tasks.prepare_update_changeset(task, %{status: "IN-PROGRESS"})

      updated_task = Tasks.apply_update_changeset(changeset)
      assert updated_task.status == "IN-PROGRESS"
      assert updated_task.id == task.id
    end

    test "returns error for invalid changeset" do
      {:ok, task} = Tasks.create_task(%{description: "Test task", status: "PENDING"})

      changeset = Tasks.prepare_update_changeset(task, %{description: ""})

      assert {:error, invalid_changeset} = Tasks.apply_update_changeset(changeset)
      refute invalid_changeset.valid?
    end

    test "converts UTC times to local timezone" do
      {:ok, task} = Tasks.create_task(%{description: "Test task", status: "PENDING"})

      local_time = ~N[2025-01-15 14:30:00]
      changeset = Tasks.prepare_update_changeset(task, %{started_at: local_time})

      updated_task = Tasks.apply_update_changeset(changeset)
      assert updated_task.started_at != nil
      assert updated_task.started_at.time_zone == "America/New_York"
    end
  end

  describe "persist_update_changeset/1" do
    test "persists valid changeset to database" do
      {:ok, task} = Tasks.create_task(%{description: "Test task", status: "PENDING"})

      changeset = Tasks.prepare_update_changeset(task, %{status: "IN-PROGRESS"})

      assert {:ok, updated_task} = Tasks.persist_update_changeset(changeset)
      assert updated_task.status == "IN-PROGRESS"

      assert {:ok, persisted_task} = Tasks.get_task(task.id)
      assert persisted_task.status == "IN-PROGRESS"
    end

    test "returns error for invalid changeset" do
      {:ok, task} = Tasks.create_task(%{description: "Test task", status: "PENDING"})

      changeset = Tasks.prepare_update_changeset(task, %{description: ""})

      assert {:error, invalid_changeset} = Tasks.persist_update_changeset(changeset)
      refute invalid_changeset.valid?
    end
  end
end
