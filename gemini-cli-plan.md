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
    *   Create the main `OpenDevCoach.Session` GenServer to manage application state.
    *   Update `lib/open_dev_coach/application.ex` to start `OpenDevCoach.Repo`, `OpenDevCoach.Session`, and `TioComodo.Repl.Server` in the supervision tree.
    *   Implement the shutdown listener process as recommended by `tio_comodo` docs to ensure a clean exit.

3.  **Terminal Interface (REPL):**
    *   Create a `OpenDevCoach.CLI.Commands` module to serve as the command provider for `tio_comodo`.
    *   Configure `tio_comodo` in `config/config.exs` to use `OpenDevCoach.CLI.Commands` as its `simple_provider`.
    *   Implement the initial commands (`/help`, `/quit`, `/exit`) as functions within the `Commands` module. These functions will return appropriate tuples like `{:ok, "message"}` or `{:stop, :normal, "Goodbye!"}`.
    *   Implement a `catchall_handler` function in the `Commands` module to handle any input that is not a defined command. This will be the entry point for conversational AI interactions.

4.  **Command Logic Delegation:**
    *   The functions in `OpenDevCoach.CLI.Commands` will be a thin layer responsible for parsing command arguments.
    *   The core application logic will reside in the `OpenDevCoach.Session` GenServer. The command handlers in `CLI.Commands` will make calls (`GenServer.call`) to the `Session` process to execute tasks, manage configuration, etc.

## Phase 2: Task & Configuration Management

This phase implements the core productivity features of the application.

1.  **Task Management (`/task`):**
    *   Create an Ecto context module: `OpenDevCoach.Tasks`.
    *   Implement functions in the `Tasks` context for all task operations (list, add, update, remove).
    *   Implement the `/task` subcommands as functions in `OpenDevCoach.CLI.Commands`.
    *   These command functions will parse arguments (e.g., the task description or task number) and call the `OpenDevCoach.Session` GenServer to perform the requested task operation.
    *   Implement the logic for `/task start` to also set any other `IN-PROGRESS` tasks to `ON-HOLD`.
    *   Implement `/task backup` to query all tasks and write them to a `task_backup.md` file.

2.  **Configuration Management (`/config`):**
    *   Create an Ecto context module: `OpenDevCoach.Configuration`.
    *   Implement functions for all config operations (get, set, list, reset).
    *   Implement the `/config` subcommands in `OpenDevCoach.CLI.Commands`, which will delegate the logic to the `Session` GenServer.
    *   Ensure API keys and other sensitive data are handled appropriately (the database file should be in `.gitignore`).

## Phase 3: AI Provider Abstraction & Integration

This phase focuses on connecting the application to various AI services.

1.  **AI Provider Behaviour:**
    *   Define a new behaviour, `OpenDevCoach.AI.Provider`, that specifies the contract for all AI clients, e.g., a `chat(messages, tool_definitions)` function.

2.  **Provider Implementations:**
    *   Create a directory `lib/open_dev_coach/ai/providers/`.
    *   Add necessary HTTP client (`req`) and JSON (`jason`) libraries.
    *   Implement a module for each provider (`Gemini`, `OpenAI`, `Anthropic`, `Ollama`) that adopts the `Provider` behaviour.
    *   Create a factory module, `OpenDevCoach.AI`, that reads the `ai_provider` from the configuration and delegates calls to the appropriate provider module.

3.  **AI Integration:**
    *   The `catchall_handler` function in `OpenDevCoach.CLI.Commands` will pass the user's input to the `OpenDevCoach.Session` GenServer.
    *   The `Session` GenServer will then call the `OpenDevCoach.AI.chat/2` function, manage the conversation history in the `agent_history` table, and return the response.
    *   Implement the `/config test` command to send a simple "Hello" message to the configured AI and report success or failure.

## Phase 4: Scheduler & Notifications

This phase makes the application proactive by introducing scheduled check-ins and desktop alerts.

1.  **Check-in Scheduler:**
    *   Note that checkins are scheduled for one point in time only. Recurring checkins may be added later.
    *   Create a `OpenDevCoach.Scheduler` GenServer and add it to the supervision tree.
    *   The `Scheduler` will be responsible for managing scheduled check-ins using `Process.send_after/3`.
    *   When a check-in is triggered, the `Scheduler` will send a `:checkin` message to the `Session` process.
    *   Implement the `/checkin` commands in `OpenDevCoach.CLI.Commands` to interact with the `Scheduler` GenServer.

2.  **Desktop Notifications:**
    *   Create a `OpenDevCoach.Notifier` module with a `notify(title, message)` function.
    *   This function will use `System.cmd/3` to execute the appropriate command-line tool (`notify-send` for Linux, `terminal-notifier` for macOS).

3.  **Handling Check-ins:**
    *   In the `Session` GenServer, implement `handle_info(:checkin, state)`.
    *   This function will gather context (agent history, tasks), format a prompt, call the AI provider, display the response via `TioComodo`, and trigger a desktop notification via `OpenDevCoach.Notifier`.

## Phase 5: Polish & Refinement

This final phase focuses on improving the user experience and adding more "coach-like" intelligence.

1.  **UI/UX Enhancements:**
    *   Use `TioComodo`'s colorscheme configuration and `Owl` features to add color and formatting to the output for task lists, statuses, and AI responses.
    *   Implement loading spinners or progress indicators for long-running operations like AI calls.

2.  **Prompt Engineering:**
    *   Refine the system prompts used for check-ins to make the AI more encouraging, insightful, and helpful, acting as a personal developer coach.

3.  **Testing:**
    *   Write ExUnit tests for the core logic, especially Ecto contexts and the `Session` GenServer state transitions.

4.  **Documentation:**
    *   Improve the `/help` command to be more detailed.
    *   Add module (`@moduledoc`) and function (`@doc`) documentation.
    *   Update the `README.md` with setup and usage instructions.