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
      {message, new_state} = Impl.add_task(state, "New task description")

      assert length(new_state.tasks) == 1
      assert hd(new_state.tasks).description == "New task description"
      assert hd(new_state.tasks).status == "PENDING"
      assert message =~ "Your Tasks:"
    end

    test "returns formatted task list", %{state: state} do
      {message, _new_state} = Impl.add_task(state, "Test task")

      assert message =~ "Your Tasks:"
      assert message =~ "Test task"
      assert message =~ "[PENDING]"
    end
  end

  describe "list_tasks/1" do
    test "returns message for empty task list" do
      state = %{tasks: []}
      {message, returned_state} = Impl.list_tasks(state)

      assert message == "No tasks found. Add one with `/task add <description>`"
      assert returned_state == state
    end

    test "returns formatted task list with tasks" do
      tasks = [
        %TaskSchema{description: "First task", status: "PENDING"},
        %TaskSchema{description: "Second task", status: "IN-PROGRESS"},
        %TaskSchema{description: "Third task", status: "COMPLETED"}
      ]

      state = %{tasks: tasks}

      {message, returned_state} = Impl.list_tasks(state)

      assert message =~ "Your Tasks:"
      assert message =~ "First task"
      assert message =~ "Second task"
      assert message =~ "Third task"
      assert message =~ "[PENDING]"
      assert message =~ "[IN-PROGRESS]"
      assert message =~ "[COMPLETED]"
      assert returned_state == state
    end
  end

  describe "start_task/2" do
    setup do
      tasks = [
        %TaskSchema{description: "Task 1", status: "PENDING"},
        %TaskSchema{description: "Task 2", status: "PENDING"},
        %TaskSchema{description: "Task 3", status: "PENDING"}
      ]

      state = %{tasks: tasks}
      %{state: state}
    end

    test "starts a task by ordinal number", %{state: state} do
      {_message, new_state} = Impl.start_task(state, 2)

      assert Enum.at(new_state.tasks, 1).status == "IN-PROGRESS"
    end

    test "puts other IN-PROGRESS tasks on hold", %{state: state} do
      # First set task 1 to IN-PROGRESS
      state_with_progress = %{
        state
        | tasks: List.update_at(state.tasks, 0, &%{&1 | status: "IN-PROGRESS"})
      }

      {_message, new_state} = Impl.start_task(state_with_progress, 2)

      assert Enum.at(new_state.tasks, 0).status == "ON-HOLD"
      assert Enum.at(new_state.tasks, 1).status == "IN-PROGRESS"
    end

    test "returns original state for invalid task ordinal", %{state: state} do
      returned_state = Impl.start_task(state, 0)

      assert returned_state == state
    end

    test "returns original state for task ordinal out of range", %{state: state} do
      returned_state = Impl.start_task(state, 10)

      assert returned_state == state
    end
  end

  describe "complete_task/2" do
    setup do
      tasks = [
        %TaskSchema{description: "Task 1", status: "PENDING"},
        %TaskSchema{description: "Task 2", status: "IN-PROGRESS"}
      ]

      state = %{tasks: tasks}
      %{state: state}
    end

    test "completes a task by ordinal number", %{state: state} do
      new_state = Impl.complete_task(state, 1)

      assert Enum.at(new_state.tasks, 0).status == "COMPLETED"
    end

    test "returns original state on error", %{state: state} do
      returned_state = Impl.complete_task(state, 0)

      assert returned_state == state
    end
  end

  describe "remove_task/2" do
    setup do
      tasks = [
        %TaskSchema{description: "Task 1", status: "PENDING"},
        %TaskSchema{description: "Task 2", status: "IN-PROGRESS"},
        %TaskSchema{description: "Task 3", status: "COMPLETED"}
      ]

      state = %{tasks: tasks}
      %{state: state}
    end

    test "removes a task by ordinal number", %{state: state} do
      new_state = Impl.remove_task(state, 2)

      assert length(new_state.tasks) == 2
      assert Enum.at(new_state.tasks, 0).description == "Task 1"
      assert Enum.at(new_state.tasks, 1).description == "Task 3"
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
      {{:ok, message}, returned_state} = Impl.get_config(state, "timezone")

      assert message == "timezone: America/New_York"
      assert returned_state == state
    end

    test "returns not found message when key doesn't exist", %{state: state} do
      {{:ok, message}, returned_state} = Impl.get_config(state, "nonexistent")

      assert message == "Configuration key 'nonexistent' not found"
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
    test "returns message for empty configuration" do
      state = %{config: %{}}
      {{:ok, message}, returned_state} = Impl.list_configs(state)

      assert message == "No configurations set. Use `/config set <key> <value>` to add some."
      assert returned_state == state
    end

    test "returns formatted configuration list" do
      config = %{"timezone" => "America/New_York", "ai_model" => "gpt-4"}
      state = %{config: config}
      {{:ok, message}, returned_state} = Impl.list_configs(state)

      assert message =~ "Current Configurations:"
      assert message =~ "timezone: America/New_York"
      assert message =~ "ai_model: gpt-4"
      assert returned_state == state
    end

    test "redacts sensitive configuration values" do
      config = %{"ai_api_key" => "secret-key", "timezone" => "America/New_York"}
      state = %{config: config}
      {{:ok, message}, returned_state} = Impl.list_configs(state)

      assert message =~ "ai_api_key: ***"
      assert message =~ "timezone: America/New_York"
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
