defmodule OpenDevCoach.CLI.Commands do
  @moduledoc """
  Command handler for the OpenDevCoach REPL.

  This module provides the command interface for tio_comodo,
  handling basic commands and routing non-commands to the AI system.
  """

  @doc """
  Returns the map of available commands for the REPL.
  """
  def commands do
    %{
      "help" => {__MODULE__, :help, []},
      "quit" => {__MODULE__, :quit, []},
      "catchall_handler" => {__MODULE__, :handle_unknown, []}
    }
  end

  @doc """
  Displays help information for available commands.
  """
  def help(_args) do
    help_text = """
    OpenDevCoach - Your Personal Developer Coach

    Available Commands:
      /help          - Show this help message
      /quit          - Exit the application

    Any other input will be sent to your AI coach for assistance.
    """

    {:ok, help_text}
  end

  @doc """
  Exits the application cleanly.
  """
  def quit(_args) do
    {:stop, :normal, "Goodbye! Keep coding and stay productive! 👨‍💻"}
  end

  @doc """
  Handles any input that doesn't match a defined command.

  For now, this echoes back the input. In future PRs, this will
  route to the AI system for coaching and assistance.
  """
  def handle_unknown(input) do
    {:ok, "You said: #{input}\n\nThis will be sent to your AI coach in future updates!"}
  end
end
