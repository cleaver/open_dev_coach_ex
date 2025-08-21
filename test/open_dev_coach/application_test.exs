defmodule OpenDevCoach.ApplicationTest do
  use ExUnit.Case, async: false

  test "REPL responds to basic commands" do
    # This test verifies the command structure is correct
    commands = OpenDevCoach.CLI.Commands.commands()
    assert Map.has_key?(commands, "/help")
    assert Map.has_key?(commands, "/quit")
    assert Map.has_key?(commands, "/task")
    assert Map.has_key?(commands, "/config")
  end

  test "quit command returns correct stop tuple" do
    # This test verifies the quit command returns the correct tuple
    # that signals tio_comodo to stop
    result = OpenDevCoach.CLI.Commands.quit([])
    assert elem(result, 0) == :stop
    assert elem(result, 1) == :normal
  end

  test "application can be started and stopped independently" do
    # Test that we can start a separate instance of the application
    # without interfering with the main test application
    case OpenDevCoach.Application.start(:test, []) do
      {:ok, pid} ->
        # Verify it started correctly
        assert Process.alive?(pid)

        # Clean up this test instance
        Process.exit(pid, :normal)

        # Give it time to shut down
        Process.sleep(10)

        # Verify it's no longer running
        refute Process.alive?(pid)

      {:error, {:already_started, _pid}} ->
        # Application is already started, which is fine
        :ok
    end
  end
end
