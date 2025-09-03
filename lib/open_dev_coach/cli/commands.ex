defmodule OpenDevCoach.CLI.Commands do
  @moduledoc """
  Command handler for the OpenDevCoach REPL.

  This module provides the command interface for tio_comodo,
  handling basic commands and routing non-commands to the AI system.
  """

  alias OpenDevCoach.CLI.CheckinCommands
  alias OpenDevCoach.CLI.ConfigCommands
  alias OpenDevCoach.CLI.TaskCommands

  @doc """
  Returns the map of available commands for the REPL.
  """
  def commands do
    %{
      "/help" => {__MODULE__, :help, []},
      "/quit" => {__MODULE__, :quit, []},
      "/task" => {TaskCommands, :dispatch, []},
      "/config" => {ConfigCommands, :dispatch, []},
      "/checkin" => {CheckinCommands, :dispatch, []},
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

    Task Management:
      /task add <description>     - Add a new task
      /task list                  - List all tasks
      /task start <number>        - Start working on a task
      /task complete <number>     - Mark a task as completed
      /task remove <number>       - Remove a task
      /task backup                - Create backup of all tasks

    Check-in Management:
      /checkin add <time>         - Schedule a check-in (e.g., '09:30' or '2h 30m')
      /checkin list               - List all scheduled check-ins
      /checkin remove <id>        - Remove a scheduled check-in
      /checkin status             - Show status of all check-ins

    Configuration:
      /config set <key> <value>   - Set a configuration value
      /config get <key>           - Get a configuration value
      /config list                - List all configurations
      /config reset               - Reset all configurations
      /config keys                - Show valid configuration keys
      /config test                - Test your AI configuration
      /config timezone            - Show current timezone
      /config timezone <zone>     - Set timezone (e.g., 'America/New_York')

    AI Coaching:
      Any other input will be sent to your AI coach for assistance.
      The AI will have access to your task list and conversation history.

    Configuration Keys:
      • ai_provider  - AI service to use (gemini, openai, anthropic, ollama)
      • ai_model     - Model name for the provider
      • ai_api_key   - API key for external AI services
      • timezone     - Your local timezone for scheduling check-ins
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

  This function routes user input to the AI coach for assistance.
  """
  def handle_unknown(input) do
    case OpenDevCoach.Session.chat_with_ai(input) do
      {:ok, response} ->
        {:ok, response}

      {:error, reason} ->
        {:error, "AI service error: #{reason}"}
    end
  end
end
