defmodule OpenDevCoach.TasksTest do
  use OpenDevCoach.DataCase, async: false

  alias OpenDevCoach.Tasks

  describe "add_task/1" do
    test "creates a task with a valid description" do
      assert {:ok, task} = Tasks.add_task("A new task")
      assert task.description == "A new task"
      assert task.status == "PENDING"
    end

    test "returns an error for an empty description" do
      assert {:error, "Task description cannot be empty"} = Tasks.add_task("")
    end

    test "returns an error for a nil description" do
      assert {:error, "Task description cannot be empty"} = Tasks.add_task(nil)
    end
  end
end
