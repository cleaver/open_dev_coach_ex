# OpenDevCoach Task List

This file breaks down the implementation plan into a series of pull requests with actionable tasks for a single developer, updated to reflect the correct `tio_comodo` integration.

## Pull Request 1: Core Application Setup & Database Integration

**Goal:** Establish the project's foundation with database connectivity and basic application structure.

- [x] **Project Dependencies:**
    - [x] Add `ecto_sqlite3` and `ecto` to `mix.exs`.
    - [x] Run `mix deps.get`.
- [x] **Ecto Configuration:**
    - [x] Create `OpenDevCoach.Repo` module.
    - [x] Configure the repo in `config/config.exs` for dev, test, and prod environments.
- [x] **Database Migrations:**
    - [x] Create an initial migration for the `tasks` table.
    - [x] Create a migration for the `configurations` table.
    - [x] Create a migration for the `checkins` table.
    - [x] Create a migration for the `agent_history` table.
- [x] **Database Setup:**
    - [x] Run `mix ecto.create`.
    - [x] Run `mix ecto.migrate`.
- [x] **Application Supervision:**
    - [x] Add `OpenDevCoach.Repo` to the supervision tree in `lib/open_dev_coach/application.ex`.

## Pull Request 2: Interactive REPL Setup

**Goal:** Make the application interactive by correctly setting up `tio_comodo` and its command handler.

- [x] **Session GenServer:**
    - [x] Create the main `OpenDevCoach.Session` GenServer for state management.
    - [x] Add the `Session` GenServer to the supervision tree.
- [x] **CLI Command Handler:**
    - [x] Create the `OpenDevCoach.CLI.Commands` module.
    - [x] Implement a `commands/0` function that returns a map for `/help` and `/quit`.
    - [x] Implement the `hello/1` and `quit/1` functions.
    - [x] Implement a `handle_unknown/1` catchall function that echoes the input for now.
- [x] **TioComodo Configuration:**
    - [x] In `config/config.exs`, configure `tio_comodo` to use `OpenDevCoach.CLI.Commands` as the `simple_provider` and `catchall_handler`.
- [x] **Supervisor Integration:**
    - [x] In `lib/open_dev_coach/application.ex`, add `TioComodo.Repl.Server` to the supervision tree.
    - [x] Add the `spawn_link` process for listening to `:repl_terminated` to ensure clean shutdown, as shown in the `tio_comodo` documentation.

## Pull Request 3: Task Management Feature

**Goal:** Implement the full suite of task management commands.

- [x] **Ecto Context:**
    - [x] Create the `OpenDevCoach.Tasks` context module.
    - [x] Implement `list_tasks/0`, `add_task/1`, `get_task/1`, `update_task_status/2`, and `remove_task/1`.
- [x] **Session Logic:**
    - [x] Implement corresponding functions in the `OpenDevCoach.Session` GenServer that call the `Tasks` context.
- [x] **Command Integration:**
    - [x] In `OpenDevCoach.CLI.Commands`, implement the functions for `/task add`, `/task list`, `/task start`, `/task complete`, and `/task remove`.
    - [x] These functions will parse arguments and call the `Session` GenServer to execute the logic.
- [x] **Backup Feature:**
    - [x] Implement the `/task backup` command in `CLI.Commands` and the backing logic in the `Session` GenServer.

## Pull Request 4: Configuration Management Feature

**Goal:** Allow users to configure the application, especially for AI settings.

- [ ] **Ecto Context:**
    - [ ] Create the `OpenDevCoach.Configuration` context module.
    - [ ] Implement `get_config/1`, `set_config/2`, `list_configs/0`, and `reset_config/0`.
- [ ] **Session Logic:**
    - [ ] Add functions to the `Session` GenServer to handle configuration logic by calling the `Configuration` context.
- [ ] **Command Integration:**
    - [ ] Implement the `/config` subcommands (`set`, `get`, `list`, `reset`) in `CLI.Commands`, delegating to the `Session` GenServer.
- [ ] **Gitignore:**
    - [ ] Ensure the SQLite database file is added to `.gitignore`.

## Pull Request 5: AI Provider Abstraction & Integration

**Goal:** Create a flexible architecture for supporting multiple AI providers and integrate it into the REPL.

- [ ] **AI Provider Behaviour:**
    - [ ] Define the `OpenDevCoach.AI.Provider` behaviour with a `chat/2` function specification.
- [ ] **Provider Implementations:**
    - [ ] Add `req` and `jason` to `mix.exs`.
    - [ ] Create and implement the provider modules: `Gemini`, `OpenAI`, `Anthropic`, and `Ollama`.
- [ ] **AI Factory:**
    - [ ] Create the `OpenDevCoach.AI` factory module to delegate to the correct provider based on config.
- [ ] **REPL Integration:**
    - [ ] Modify the `handle_unknown/1` function in `CLI.Commands` to pass input to the `Session` GenServer.
    - [ ] Implement the AI chat logic in the `Session` GenServer, which will call the `AI` module and manage `agent_history`.
    - [ ] Implement the `/config test` command.

## Pull Request 6: Scheduler & Check-in Management

**Goal:** Add proactive check-ins by implementing a scheduler and the `/checkin` commands.

- [ ] **Scheduler GenServer:**
    - [ ] Create and implement the `OpenDevCoach.Scheduler` GenServer.
    - [ ] Add the `Scheduler` to the supervision tree.
- [ ] **Scheduling Logic:**
    - [ ] The `Scheduler` should use `Process.send_after/3` to send a `:checkin` message to the `Session` process.
- [ ] **Command Integration:**
    - [ ] Implement the `/checkin` commands in `CLI.Commands`. These will call the `Scheduler` GenServer to manage check-in times.
- [ ] **Check-in Handling:**
    - [ ] Implement the `handle_info(:checkin, state)` callback in the `Session` GenServer to gather context, call the AI, and display the result.

## Pull Request 7: Desktop Notifications & Final Polish

**Goal:** Add desktop notifications for check-ins and improve the overall user experience.

- [ ] **Notifier Module:**
    - [ ] Create the `OpenDevCoach.Notifier` module with a `notify/2` function that calls the appropriate OS-specific command-line tool.
- [ ] **Integration:**
    - [ ] Call `Notifier.notify/2` from the `Session`'s `:checkin` handler.
- [ ] **UI/UX Enhancements:**
    - [ ] Configure the `tio_comodo` colorscheme in `config/config.exs`.
    - [ ] Use `Owl` within the `CLI.Commands` module to add color and formatting to command output.
    - [ ] Add a loading message before long-running calls (e.g., to the AI).
- [ ] **Prompt Engineering:**
    - [ ] Refine the system prompt used in the `Session` GenServer for check-ins.
- [ ] **Testing & Documentation:**
    - [ ] Write ExUnit tests for key modules.
    - [ ] Update the `README.md` with full setup and usage instructions.
    - [ ] Add `@moduledoc` and `@doc` annotations.