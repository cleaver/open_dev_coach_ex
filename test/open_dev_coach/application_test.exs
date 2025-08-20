defmodule OpenDevCoach.ApplicationTest do
  use ExUnit.Case, async: false

  setup do
    # Clean up any existing processes before each test
    if Process.whereis(OpenDevCoach.Supervisor) do
      Supervisor.stop(OpenDevCoach.Supervisor)
      Process.sleep(10)
    end

    :ok
  end

  test "application starts with REPL server" do
    # Start the application
    {:ok, _pid} = OpenDevCoach.Application.start(:normal, [])

    # Verify the REPL server is running
    assert Process.whereis(OpenDevCoach.Repl)

    # Clean up
    Supervisor.stop(OpenDevCoach.Supervisor)
  end

  test "REPL responds to basic commands" do
    # This test would require more complex setup to actually test REPL interaction
    # For now, we just verify the command structure is correct
    commands = OpenDevCoach.CLI.Commands.commands()
    assert Map.has_key?(commands, "help")
    assert Map.has_key?(commands, "quit")
  end

  test "application shuts down cleanly on quit" do
    # This test verifies the quit command returns the correct tuple
    # that signals tio_comodo to stop
    result = OpenDevCoach.CLI.Commands.quit([])
    assert elem(result, 0) == :stop
    assert elem(result, 1) == :normal
  end
end
