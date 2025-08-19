# OpenDevCoach Implementation Plan

This document outlines a detailed plan to build the OpenDevCoach application based on the initial specification. The plan is divided into phases to ensure a structured and iterative development process.

## Phase 1: Project Foundation & Core Architecture

This phase focuses on setting up the essential boilerplate, database, and the main application loop.

1.  **Ecto & Database Setup:**
    *   Add `ecto_sqlite3` to `mix.exs` dependencies.
    *   Create the application's `Repo` module (`OpenDevCoach.Repo`).
    *   Configure Ecto in `config/config.exs` to use the SQLite adapter.
    *   Create initial migrations for the required tables:
        *   `tasks`: `description` (text), `status` (string, default: 'PENDING'), `started_at` (datetime), `completed_at` (datetime).
        *   `checkins`: `scheduled_at` (datetime), `status` (string, default: 'PENDING').
        *   `configurations`: `key` (string, unique), `value` (text).
        *   `agent_history`: `role` (string), `content` (text), `timestamp` (datetime).
    *   Run `mix ecto.create` and `mix ecto.migrate`.

2.  **Application Supervision:**
    *   Update `lib/open_dev_coach/application.ex` to start the `OpenDevCoach.Repo` and a new `OpenDevCoach.Session` GenServer.
    *   Consider a `DynamicSupervisor` for managing scheduled check-in processes later.

3.  **Terminal Interface (REPL):**
    *   Create the main `OpenDevCoach.Session` GenServer. This will manage the application's primary state.
    *   In the `Session` GenServer, integrate `TioComodo` to handle user input and display output.
    *   Implement a basic Read-Eval-Print Loop (REPL) that can distinguish between commands (starting with `/`) and conversational input.
    *   Implement the initial commands: `/help` (displaying a static list of commands) and `/quit` or `/exit` to gracefully shut down the application.

4.  **Command Parsing:**
    *   Create a module `OpenDevCoach.CommandParser` with a `parse/1` function that takes the raw user input string and returns a structured command, e.g., `{:ok, {:task, :add, "Implement AI integration"}}` or `{:error, :not_a_command}`.

## Phase 2: Task & Configuration Management

This phase implements the core productivity features of the application.

1.  **Task Management (`/task`):**
    *   Create an Ecto context module: `OpenDevCoach.Tasks`.
    *   Implement functions in the `Tasks` context for all task operations:
        *   `list_tasks()`
        *   `add_task(description)`
        *   `get_task(id)`
        *   `update_task_status(task, status)` (Handles `start`, `complete`, `on-hold`)
        *   `remove_task(task)`
    *   Integrate these context functions into the `Session` GenServer to handle the `/task` subcommands (`add`, `list`, `start`, `complete`, `remove`).
    *   Implement the logic for `/task start` to also set any other `IN-PROGRESS` tasks to `ON-HOLD`.
    *   Implement `/task backup` to query all tasks and write them to a `task_backup.md` file using a Markdown checklist format.

2.  **Configuration Management (`/config`):**
    *   Create an Ecto context module: `OpenDevCoach.Configuration`.
    *   Implement functions for `get_config(key)`, `set_config(key, value)`, `list_configs()`, and `reset_config()`.
    *   Integrate these functions to handle the `/config` subcommands.
    *   Ensure API keys and other sensitive data are handled appropriately (the database file should be in `.gitignore`).

## Phase 3: AI Provider Abstraction & Integration

This phase focuses on connecting the application to various AI services.

1.  **AI Provider Behaviour:**
    *   Define a new behaviour, `OpenDevCoach.AI.Provider`, that specifies the contract for all AI clients.
    *   The behaviour should define a primary function, e.g., `chat(messages, tool_definitions)`, which will handle the core logic of sending a conversation history and receiving a response.

2.  **Provider Implementations:**
    *   Create a directory `lib/open_dev_coach/ai/providers/`.
    *   Add the necessary HTTP client libraries (e.g., `req`) and JSON libraries (`jason`).
    *   Implement a module for each provider that adopts the `Provider` behaviour:
        *   `OpenDevCoach.AI.Providers.Gemini`
        *   `OpenDevCoach.AI.Providers.OpenAI`
        *   `OpenDevCoach.AI.Providers.Anthropic`
        *   `OpenDevCoach.AI.Providers.Ollama`
    *   Create a factory module, `OpenDevCoach.AI`, that reads the `ai_provider` from the configuration and delegates calls to the appropriate provider module.

3.  **AI Integration:**
    *   In the `Session` GenServer, handle any user input that is not a command by sending it to the configured AI provider via `OpenDevCoach.AI.chat/2`.
    *   Store the conversation in the `agent_history` table.
    *   Implement the `/config test` command to send a simple "Hello" message to the configured AI and report success or failure.

## Phase 4: Scheduler & Notifications

This phase makes the application proactive by introducing scheduled check-ins and desktop alerts.

1.  **Check-in Scheduler:**
    *   Create a `OpenDevCoach.Scheduler` GenServer.
    *   This GenServer will be responsible for managing scheduled check-ins. It will maintain a list of scheduled times in its state.
    *   When a check-in is added (`/checkin add`), the `Scheduler` will use `Process.send_after/3` to send a `:checkin` message to the `Session` process at the specified time.
    *   Implement the `/checkin` commands (`add`, `list`, `remove`, `status`) to interact with the `Scheduler` GenServer. The `add` command needs to parse both `HH:MM` and interval formats.

2.  **Desktop Notifications:**
    *   Create a `OpenDevCoach.Notifier` module.
    *   Implement a `notify(title, message)` function.
    *   Inside this function, determine the operating system (`:os.type()`).
    *   Use `System.cmd/3` to execute the appropriate command-line tool:
        *   **Linux:** `notify-send`
        *   **macOS:** `terminal-notifier` (This may require instructing the user to install it via Homebrew).
    *   Provide clear error messages if the notification tool is not found.

3.  **Handling Check-ins:**
    *   In the `Session` GenServer, implement `handle_info(:checkin, state)`.
    *   When this message is received, the `Session` will:
        1.  Gather context: the last few messages from `agent_history`, the current task list from `Tasks`, and the output from the last check-in.
        2.  Format this context into a prompt for the AI.
        3.  Call `OpenDevCoach.AI.chat/2`.
        4.  Display the AI's response in the terminal.
        5.  Call `OpenDevCoach.Notifier.notify/2` to alert the user that a check-in has occurred.

## Phase 5: Polish & Refinement

This final phase focuses on improving the user experience and adding more "coach-like" intelligence.

1.  **UI/UX Enhancements:**
    *   Use `TioComodo`'s features to add color and formatting to the output for task lists, statuses, and AI responses to improve readability.
    *   Implement loading spinners or progress indicators for long-running operations like AI calls.

2.  **Prompt Engineering:**
    *   Refine the system prompts used for check-ins to make the AI more encouraging, insightful, and helpful. The prompt should encourage the AI to act as a personal developer coach, asking clarifying questions, suggesting strategies, and providing motivation.

3.  **Testing:**
    *   Write ExUnit tests for the core logic, especially:
        *   `CommandParser` module.
        *   `Tasks`, `Configuration`, and other Ecto contexts.
        *   State transitions in the `Session` GenServer.

4.  **Documentation:**
    *   Improve the `/help` command to be more detailed and dynamic.
    *   Add module documentation (`@moduledoc`) and function documentation (`@doc`) to the code.
    *   Update the `README.md` with instructions on how to set up and use the application.
