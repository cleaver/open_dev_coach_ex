defmodule OpenDevCoach.SessionTest do
  use ExUnit.Case, async: false

  setup do
    # Clean up any existing session before each test
    if Process.whereis(OpenDevCoach.Session) do
      Process.exit(Process.whereis(OpenDevCoach.Session), :kill)
      # Give it time to die
      Process.sleep(10)
    end

    :ok
  end

  test "start_link/1 starts the GenServer with initial state" do
    assert {:ok, pid} = OpenDevCoach.Session.start_link([])
    assert Process.alive?(pid)
    # Don't exit here since it's a named process
  end

  test "init/1 returns empty state" do
    {:ok, state} = OpenDevCoach.Session.init([])
    assert state == %{}
  end

  test "handle_call/3 returns ok tuple for unknown calls" do
    # Use the existing named process if it exists, otherwise start a new one
    pid =
      case Process.whereis(OpenDevCoach.Session) do
        nil ->
          {:ok, new_pid} = OpenDevCoach.Session.start_link([])
          new_pid

        existing_pid ->
          existing_pid
      end

    response = GenServer.call(pid, :unknown_call)
    assert response == {:ok, "Not implemented yet"}
  end
end
