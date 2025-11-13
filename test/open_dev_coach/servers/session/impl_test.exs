defmodule OpenDevCoach.Servers.Session.ImplTest do
  use OpenDevCoach.DataCase, async: false

  alias OpenDevCoach.Servers.Session.Impl
  alias OpenDevCoach.Tasks.Task, as: TaskSchema

  # Helper function to compare DateTime or NaiveDateTime values
  defp compare_datetime(dt1, dt2) do
    cond do
      match?(%DateTime{}, dt1) and match?(%DateTime{}, dt2) ->
        DateTime.compare(dt1, dt2)

      match?(%NaiveDateTime{}, dt1) and match?(%NaiveDateTime{}, dt2) ->
        NaiveDateTime.compare(dt1, dt2)

      match?(%NaiveDateTime{}, dt1) ->
        dt1_as_dt = DateTime.from_naive!(dt1, "Etc/UTC")
        DateTime.compare(dt1_as_dt, dt2)

      match?(%NaiveDateTime{}, dt2) ->
        dt2_as_dt = DateTime.from_naive!(dt2, "Etc/UTC")
        DateTime.compare(dt1, dt2_as_dt)

      true ->
        NaiveDateTime.compare(DateTime.to_naive(dt1), DateTime.to_naive(dt2))
    end
  end

  describe "init/1" do
    test "initializes session state with proper structure" do
      # This test will use the actual modules since we're testing the implementation
      # The init function calls external modules, so we'll test the structure
      state = Impl.init([])

      assert is_list(state.configs)
      assert state.self == OpenDevCoach.Servers.Session
      assert is_list(state.tasks)
    end
  end

  describe "add_task/2" do
    setup do
      base_state = %{
        configs: [],
        self: OpenDevCoach.Servers.Session,
        tasks: []
      }

      %{state: base_state}
    end

    test "adds a new task to the state", %{state: state} do
      {{:ok, tasks}, new_state} = Impl.add_task(state, "New task description")

      assert length(new_state.tasks) == 1
      assert hd(new_state.tasks).description == "New task description"
      assert hd(new_state.tasks).status == "PENDING"
      assert length(tasks) == 1
      {task, _ordinal} = hd(tasks)
      assert task.description == "New task description"
    end

    test "returns task list", %{state: state} do
      {{:ok, tasks}, _new_state} = Impl.add_task(state, "Test task")

      assert is_list(tasks)
      assert length(tasks) == 1
      {task, _ordinal} = hd(tasks)
      assert task.description == "Test task"
      assert task.status == "PENDING"
    end
  end

  describe "list_tasks/1" do
    test "returns empty list for empty task list" do
      state = %{tasks: []}
      {{:ok, tasks}, returned_state} = Impl.list_tasks(state)

      assert tasks == []
      assert returned_state == state
    end

    test "returns task list" do
      now = Timex.now()

      task_list = [
        %TaskSchema{
          id: Ecto.UUID.generate(),
          description: "First task",
          status: "PENDING",
          inserted_at: Timex.shift(now, hours: -3)
        },
        %TaskSchema{
          id: Ecto.UUID.generate(),
          description: "Second task",
          status: "IN-PROGRESS",
          inserted_at: Timex.shift(now, hours: -2)
        },
        %TaskSchema{
          id: Ecto.UUID.generate(),
          description: "Third task",
          status: "COMPLETED",
          inserted_at: Timex.shift(now, hours: -1)
        }
      ]

      state = %{tasks: task_list}

      {{:ok, tasks}, returned_state} = Impl.list_tasks(state)

      assert length(tasks) == 3
      # Tasks are sorted by inserted_at descending (newest first)
      {task, _ordinal} = hd(tasks)
      assert task.description == "Third task"
      assert returned_state == state
    end
  end

  describe "start_task/2" do
    setup do
      alias OpenDevCoach.Tasks

      now = Timex.now()

      # Persist tasks to database first
      {:ok, task1} =
        Tasks.create_task(%{
          id: Ecto.UUID.generate(),
          description: "Task 1",
          status: "PENDING",
          inserted_at: Timex.shift(now, hours: -3)
        })

      {:ok, task2} =
        Tasks.create_task(%{
          id: Ecto.UUID.generate(),
          description: "Task 2",
          status: "PENDING",
          inserted_at: Timex.shift(now, hours: -2)
        })

      {:ok, task3} =
        Tasks.create_task(%{
          id: Ecto.UUID.generate(),
          description: "Task 3",
          status: "PENDING",
          inserted_at: Timex.shift(now, hours: -1)
        })

      tasks = [task1, task2, task3]
      state = %{tasks: tasks}
      %{state: state}
    end

    test "starts a task by ordinal number", %{state: state} do
      {{:ok, tasks}, new_state} = Impl.start_task(state, 2)

      # Ordinal 2 is Task 2 (second newest), which should be at index 1 in sorted order
      sorted_tasks =
        new_state.tasks
        |> Enum.sort(fn t1, t2 ->
          compare_datetime(t1.inserted_at, t2.inserted_at) == :gt
        end)

      assert Enum.at(sorted_tasks, 1).status == "IN-PROGRESS"
      assert Enum.at(sorted_tasks, 1).description == "Task 2"
      assert length(tasks) == 3
    end

    test "puts other IN-PROGRESS tasks on hold", %{state: state} do
      alias OpenDevCoach.Tasks

      # First set Task 1 to IN-PROGRESS in the database
      task1 = Enum.find(state.tasks, &(&1.description == "Task 1"))
      {:ok, updated_task1} = Tasks.update_task_status(task1.id, "IN-PROGRESS")

      # Update state to reflect the change
      state_with_progress = %{
        state
        | tasks:
            Enum.map(state.tasks, fn task ->
              if task.id == task1.id, do: updated_task1, else: task
            end)
      }

      {{:ok, tasks}, new_state} = Impl.start_task(state_with_progress, 2)

      # Ordinal 2 is Task 2, which should become IN-PROGRESS
      # Task 1 should be put on hold
      sorted_tasks =
        new_state.tasks
        |> Enum.sort(fn t1, t2 ->
          compare_datetime(t1.inserted_at, t2.inserted_at) == :gt
        end)

      task1 = Enum.find(sorted_tasks, &(&1.description == "Task 1"))
      task2 = Enum.find(sorted_tasks, &(&1.description == "Task 2"))
      assert task1.status == "ON-HOLD"
      assert task2.status == "IN-PROGRESS"
      assert length(tasks) == 3
    end

    test "returns error for invalid task ordinal", %{state: state} do
      {{:error, reason}, new_state} = Impl.start_task(state, 0)

      assert reason == "Task not found"
      assert new_state == state
    end

    test "returns error for task ordinal out of range", %{state: state} do
      {{:error, reason}, new_state} = Impl.start_task(state, 10)

      assert reason == "Task not found"
      assert new_state == state
    end
  end

  describe "complete_task/2" do
    setup do
      alias OpenDevCoach.Tasks

      now = Timex.now()

      # Persist tasks to database first
      {:ok, task1} =
        Tasks.create_task(%{
          id: Ecto.UUID.generate(),
          description: "Task 1",
          status: "PENDING",
          inserted_at: Timex.shift(now, hours: -2)
        })

      {:ok, task2} =
        Tasks.create_task(%{
          id: Ecto.UUID.generate(),
          description: "Task 2",
          status: "IN-PROGRESS",
          inserted_at: Timex.shift(now, hours: -1)
        })

      tasks = [task1, task2]
      state = %{tasks: tasks}
      %{state: state}
    end

    test "completes a task by ordinal number", %{state: state} do
      new_state = Impl.complete_task(state, 1)

      # Ordinal 1 is Task 2 (newest), which should be completed
      sorted_tasks =
        new_state.tasks
        |> Enum.sort(fn t1, t2 ->
          compare_datetime(t1.inserted_at, t2.inserted_at) == :gt
        end)

      assert hd(sorted_tasks).status == "COMPLETED"
      assert hd(sorted_tasks).description == "Task 2"
    end

    test "returns original state on error", %{state: state} do
      returned_state = Impl.complete_task(state, 0)

      assert returned_state == state
    end
  end

  describe "remove_task/2" do
    setup do
      now = Timex.now()

      tasks = [
        %TaskSchema{
          id: Ecto.UUID.generate(),
          description: "Task 1",
          status: "PENDING",
          inserted_at: Timex.shift(now, hours: -3)
        },
        %TaskSchema{
          id: Ecto.UUID.generate(),
          description: "Task 2",
          status: "IN-PROGRESS",
          inserted_at: Timex.shift(now, hours: -2)
        },
        %TaskSchema{
          id: Ecto.UUID.generate(),
          description: "Task 3",
          status: "COMPLETED",
          inserted_at: Timex.shift(now, hours: -1)
        }
      ]

      state = %{tasks: tasks}
      %{state: state}
    end

    test "removes a task by ordinal number", %{state: state} do
      new_state = Impl.remove_task(state, 2)

      assert length(new_state.tasks) == 2
      # Ordinal 2 is Task 2, which should be removed
      # Remaining tasks should be Task 1 and Task 3
      sorted_tasks =
        new_state.tasks
        |> Enum.sort(fn t1, t2 ->
          compare_datetime(t1.inserted_at, t2.inserted_at) == :gt
        end)

      assert length(sorted_tasks) == 2
      assert Enum.at(sorted_tasks, 0).description == "Task 3"
      assert Enum.at(sorted_tasks, 1).description == "Task 1"
    end

    test "returns original state on error", %{state: state} do
      returned_state = Impl.remove_task(state, 0)

      assert returned_state == state
    end
  end

  describe "get_config/2" do
    setup do
      alias OpenDevCoach.Configuration.Config

      configs = [
        %Config{
          id: 1,
          key: "ai_model",
          value: "gpt-4",
          inserted_at: ~N[2025-01-01 00:00:00],
          updated_at: ~N[2025-01-01 00:00:00]
        }
      ]

      state = %{configs: configs}
      %{state: state}
    end

    test "returns configuration value when key exists", %{state: state} do
      {{:ok, {key, value}}, returned_state} = Impl.get_config(state, "ai_model")

      assert key == "ai_model"
      assert value == "gpt-4"
      assert returned_state == state
    end

    test "returns error when key doesn't exist", %{state: state} do
      {{:error, key}, returned_state} = Impl.get_config(state, "nonexistent")

      assert key == "nonexistent"
      assert returned_state == state
    end
  end

  describe "set_config/3" do
    setup do
      state = %{configs: []}
      %{state: state}
    end

    test "sets a valid configuration key-value pair", %{state: state} do
      {{:ok, message}, new_state} = Impl.set_config(state, "ai_model", "gpt-4")

      assert message == "Configuration 'ai_model' set to 'gpt-4'"
      assert length(new_state.configs) == 1
      config = hd(new_state.configs)
      assert config.key == "ai_model"
      assert config.value == "gpt-4"
    end

    test "updates existing configuration", %{state: state} do
      alias OpenDevCoach.Configuration.Config

      # First set a config
      {{:ok, _}, state_with_config} = Impl.set_config(state, "ai_model", "gpt-3")

      # Then update it
      {{:ok, message}, updated_state} = Impl.set_config(state_with_config, "ai_model", "gpt-4")

      assert message == "Configuration 'ai_model' set to 'gpt-4'"
      assert length(updated_state.configs) == 1
      config = hd(updated_state.configs)
      assert config.key == "ai_model"
      assert config.value == "gpt-4"
    end

    test "returns error for invalid configuration", %{state: state} do
      {{:error, message}, returned_state} = Impl.set_config(state, "", "invalid")

      assert message =~ "can't be blank"
      assert returned_state == state
    end
  end

  describe "list_configs/1" do
    test "returns empty map for empty configuration" do
      state = %{configs: []}
      {{:ok, configs}, returned_state} = Impl.list_configs(state)

      assert configs == %{}
      assert returned_state == state
    end

    test "returns configuration map" do
      alias OpenDevCoach.Configuration.Config

      configs = [
        %Config{
          id: 1,
          key: "ai_model",
          value: "gpt-4",
          inserted_at: ~N[2025-01-01 00:00:00],
          updated_at: ~N[2025-01-01 00:00:00]
        }
      ]

      state = %{configs: configs}
      {{:ok, config_map}, returned_state} = Impl.list_configs(state)

      assert config_map == %{"ai_model" => "gpt-4"}
      assert config_map["ai_model"] == "gpt-4"
      assert returned_state == state
    end
  end

  describe "reset_config/1" do
    test "calls Configuration.reset_config and returns result" do
      alias OpenDevCoach.Configuration.Config

      configs = [
        %Config{
          id: 1,
          key: "ai_model",
          value: "gpt-4",
          inserted_at: ~N[2025-01-01 00:00:00],
          updated_at: ~N[2025-01-01 00:00:00]
        }
      ]

      state = %{configs: configs}

      {{:ok, message}, returned_state} = Impl.reset_config(state)

      # The actual result depends on the Configuration module
      assert is_binary(message)
      assert returned_state.configs == []
    end
  end

  describe "output/2" do
    test "calls ReplServer.output with message" do
      # This test verifies the function calls the external module
      # The actual behavior depends on the ReplServer implementation
      result = Impl.output(:info, "Test message")

      assert result == :ok
    end
  end

  describe "backup_tasks/1" do
    test "creates backup content with tasks" do
      tasks = [
        %TaskSchema{id: Ecto.UUID.generate(), description: "Task 1", status: "PENDING"},
        %TaskSchema{id: Ecto.UUID.generate(), description: "Task 2", status: "COMPLETED"}
      ]

      state = %{tasks: tasks}

      file_write_double = fn filename, content ->
        assert String.starts_with?(filename, "task_backup_")
        assert String.ends_with?(filename, ".md")

        assert String.contains?(content, "# Task Backup")
        assert String.contains?(content, "Task 1")
        assert String.contains?(content, "Task 2")
        assert String.contains?(content, "[PENDING]")
        assert String.contains?(content, "[COMPLETED]")

        :ok
      end

      {{:ok, message}, returned_state} = Impl.backup_tasks(state, file_write_double)

      assert message =~ "Tasks backed up to"
      assert message =~ "task_backup_"
      assert returned_state == state
    end

    test "handles empty task list" do
      state = %{tasks: []}

      # Create a test double for File.write/2
      file_write_double = fn filename, content ->
        # Verify the filename format
        assert String.starts_with?(filename, "task_backup_")
        assert String.ends_with?(filename, ".md")

        # Verify the content format for empty task list
        assert String.contains?(content, "# Task Backup")
        assert String.contains?(content, Date.utc_today() |> Date.to_string())

        :ok
      end

      {{:ok, message}, returned_state} = Impl.backup_tasks(state, file_write_double)

      assert String.contains?(message, "Tasks backed up to")
      assert returned_state == state
    end

    test "handles file write errors" do
      tasks = [
        %TaskSchema{id: Ecto.UUID.generate(), description: "Task 1", status: "PENDING"}
      ]

      state = %{tasks: tasks}

      # Create a test double that simulates a file write error
      file_write_double = fn _filename, _content ->
        {:error, :enoent}
      end

      {{:error, message}, returned_state} = Impl.backup_tasks(state, file_write_double)

      assert message =~ "Failed to backup tasks"
      assert message =~ "Failed to write backup file"
      assert returned_state == state
    end
  end
end
