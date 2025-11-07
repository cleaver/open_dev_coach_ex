defmodule OpenDevCoach.Servers.Session.ImplTest do
  use OpenDevCoach.DataCase, async: false

  alias OpenDevCoach.Servers.Session.Impl
  alias OpenDevCoach.Tasks.Task, as: TaskSchema

  describe "init/1" do
    test "initializes session state with proper structure" do
      # This test will use the actual modules since we're testing the implementation
      # The init function calls external modules, so we'll test the structure
      state = Impl.init([])

      assert is_map(state.config)
      assert state.self == OpenDevCoach.Servers.Session
      assert is_list(state.tasks)
      # Check that timezone is set (either from config or default)
      assert Map.has_key?(state.config, "timezone")
    end
  end

  describe "add_task/2" do
    setup do
      base_state = %{
        config: %{"timezone" => "America/New_York"},
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
          description: "First task",
          status: "PENDING",
          inserted_at: Timex.shift(now, hours: -3)
        },
        %TaskSchema{
          description: "Second task",
          status: "IN-PROGRESS",
          inserted_at: Timex.shift(now, hours: -2)
        },
        %TaskSchema{
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
      now = Timex.now()

      tasks = [
        %TaskSchema{
          description: "Task 1",
          status: "PENDING",
          inserted_at: Timex.shift(now, hours: -3)
        },
        %TaskSchema{
          description: "Task 2",
          status: "PENDING",
          inserted_at: Timex.shift(now, hours: -2)
        },
        %TaskSchema{
          description: "Task 3",
          status: "PENDING",
          inserted_at: Timex.shift(now, hours: -1)
        }
      ]

      state = %{tasks: tasks}
      %{state: state}
    end

    test "starts a task by ordinal number", %{state: state} do
      {{:ok, tasks}, new_state} = Impl.start_task(state, 2)

      # Ordinal 2 is Task 2 (second newest), which should be at index 1 in sorted order
      sorted_tasks =
        new_state.tasks |> Enum.sort(&(DateTime.compare(&1.inserted_at, &2.inserted_at) == :gt))

      assert Enum.at(sorted_tasks, 1).status == "IN-PROGRESS"
      assert Enum.at(sorted_tasks, 1).description == "Task 2"
      assert length(tasks) == 3
    end

    test "puts other IN-PROGRESS tasks on hold", %{state: state} do
      # First set Task 1 to IN-PROGRESS
      now = Timex.now()

      state_with_progress = %{
        state
        | tasks: [
            %TaskSchema{
              description: "Task 1",
              status: "IN-PROGRESS",
              inserted_at: Timex.shift(now, hours: -3)
            },
            %TaskSchema{
              description: "Task 2",
              status: "PENDING",
              inserted_at: Timex.shift(now, hours: -2)
            },
            %TaskSchema{
              description: "Task 3",
              status: "PENDING",
              inserted_at: Timex.shift(now, hours: -1)
            }
          ]
      }

      {{:ok, tasks}, new_state} = Impl.start_task(state_with_progress, 2)

      # Ordinal 2 is Task 2, which should become IN-PROGRESS
      # Task 1 should be put on hold
      sorted_tasks =
        new_state.tasks |> Enum.sort(&(DateTime.compare(&1.inserted_at, &2.inserted_at) == :gt))

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
      now = Timex.now()

      tasks = [
        %TaskSchema{
          description: "Task 1",
          status: "PENDING",
          inserted_at: Timex.shift(now, hours: -2)
        },
        %TaskSchema{
          description: "Task 2",
          status: "IN-PROGRESS",
          inserted_at: Timex.shift(now, hours: -1)
        }
      ]

      state = %{tasks: tasks}
      %{state: state}
    end

    test "completes a task by ordinal number", %{state: state} do
      new_state = Impl.complete_task(state, 1)

      # Ordinal 1 is Task 2 (newest), which should be completed
      sorted_tasks =
        new_state.tasks |> Enum.sort(&(DateTime.compare(&1.inserted_at, &2.inserted_at) == :gt))

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
          description: "Task 1",
          status: "PENDING",
          inserted_at: Timex.shift(now, hours: -3)
        },
        %TaskSchema{
          description: "Task 2",
          status: "IN-PROGRESS",
          inserted_at: Timex.shift(now, hours: -2)
        },
        %TaskSchema{
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
        new_state.tasks |> Enum.sort(&(DateTime.compare(&1.inserted_at, &2.inserted_at) == :gt))

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
      state = %{config: %{"timezone" => "America/New_York", "ai_model" => "gpt-4"}}
      %{state: state}
    end

    test "returns configuration value when key exists", %{state: state} do
      {{:ok, {key, value}}, returned_state} = Impl.get_config(state, "timezone")

      assert key == "timezone"
      assert value == "America/New_York"
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
      state = %{config: %{"timezone" => "America/New_York"}}
      %{state: state}
    end

    test "sets a valid configuration key-value pair", %{state: state} do
      {{:ok, message}, new_state} = Impl.set_config(state, "ai_model", "gpt-4")

      assert message == "Configuration 'ai_model' set to 'gpt-4'"
      assert new_state.config["ai_model"] == "gpt-4"
    end

    test "returns error for invalid configuration", %{state: state} do
      {{:error, message}, returned_state} = Impl.set_config(state, "", "invalid")

      assert message =~ "can't be blank"
      assert returned_state == state
    end
  end

  describe "list_configs/1" do
    test "returns empty map for empty configuration" do
      state = %{config: %{}}
      {{:ok, configs}, returned_state} = Impl.list_configs(state)

      assert configs == %{}
      assert returned_state == state
    end

    test "returns configuration map" do
      config = %{"timezone" => "America/New_York", "ai_model" => "gpt-4"}
      state = %{config: config}
      {{:ok, configs}, returned_state} = Impl.list_configs(state)

      assert configs == config
      assert configs["timezone"] == "America/New_York"
      assert configs["ai_model"] == "gpt-4"
      assert returned_state == state
    end
  end

  describe "reset_config/1" do
    test "calls Configuration.reset_config and returns result" do
      state = %{config: %{"timezone" => "America/New_York"}}

      {{:ok, message}, returned_state} = Impl.reset_config(state)

      # The actual result depends on the Configuration module
      assert is_binary(message)
      assert returned_state == state
    end
  end

  describe "update_timezone/2" do
    test "updates timezone in session state" do
      state = %{config: %{"timezone" => "America/New_York"}}
      new_state = Impl.update_timezone(state, "Europe/London")

      assert new_state.config["timezone"] == "Europe/London"
    end
  end

  describe "get_timezone/1" do
    test "returns timezone when set" do
      state = %{config: %{"timezone" => "America/New_York"}}
      {:ok, timezone} = Impl.get_timezone(state)

      assert timezone == "America/New_York"
    end

    test "returns error when timezone not set" do
      state = %{config: %{}}
      {:error, message} = Impl.get_timezone(state)

      assert message == "Session timezone not set."
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
        %TaskSchema{description: "Task 1", status: "PENDING"},
        %TaskSchema{description: "Task 2", status: "COMPLETED"}
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
        %TaskSchema{description: "Task 1", status: "PENDING"}
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
