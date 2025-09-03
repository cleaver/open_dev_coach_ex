defmodule OpenDevCoach.CLI.CommandsTest do
  use OpenDevCoach.DataCase, async: false

  alias OpenDevCoach.CLI.Commands

  # TODO: Maybe not useful tests.
  describe "CLI Commands" do
    test "commands/0 returns expected command map" do
      commands = Commands.commands()
      assert Map.has_key?(commands, "/help")
      assert Map.has_key?(commands, "/quit")
      assert Map.has_key?(commands, "/task")
      assert Map.has_key?(commands, "/config")
      assert Map.has_key?(commands, "catchall_handler")
      assert length(Map.keys(commands)) == 6
    end

    test "help/1 displays help information" do
      {:ok, help_text} = Commands.help([])
      assert String.contains?(help_text, "OpenDevCoach")
      assert String.contains?(help_text, "Available Commands")
      assert String.contains?(help_text, "/help")
      assert String.contains?(help_text, "/quit")
    end

    test "help/1 returns expected tuple structure" do
      result = Commands.help([])
      assert is_tuple(result)
      assert tuple_size(result) == 2
      assert elem(result, 0) == :ok
      assert is_binary(elem(result, 1))
    end

    test "quit/1 returns stop tuple" do
      result = Commands.quit([])
      assert elem(result, 0) == :stop
      assert elem(result, 1) == :normal
      assert String.contains?(elem(result, 2), "Goodbye")
    end

    test "quit/1 returns expected tuple structure" do
      result = Commands.quit([])
      assert is_tuple(result)
      assert tuple_size(result) == 3
      assert elem(result, 0) == :stop
      assert elem(result, 1) == :normal
      assert is_binary(elem(result, 2))
    end

    test "quit/1 tuple elements have correct types" do
      {status, reason, message} = Commands.quit([])
      assert status == :stop
      assert reason == :normal
      assert is_binary(message)
      assert String.length(message) > 0
    end

    test "handle_unknown/1 routes to AI coach" do
      test_input = "Hello, AI coach!"
      result = Commands.handle_unknown(test_input)
      # Should return an error since no AI provider is configured
      assert {:error, _} = result
      assert String.contains?(elem(result, 1), "AI service error")
    end

    test "handle_unknown/1 returns expected tuple structure" do
      result = Commands.handle_unknown("test input")
      assert is_tuple(result)
      assert tuple_size(result) == 2
      # Should return error since no AI provider is configured
      assert elem(result, 0) == :error
      assert is_binary(elem(result, 1))
    end
  end
end
