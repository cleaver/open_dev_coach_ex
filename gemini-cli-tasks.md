# OpenDevCoach Task List

This file breaks down the implementation plan into a series of pull requests with actionable tasks for a single developer.

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

## Pull Request 2: Basic REPL and Command Parsing

**Goal:** Make the application interactive with a basic Read-Eval-Print Loop (REPL) and command handling.

- [ ] **Session GenServer:**
    - [ ] Create the main `OpenDevCoach.Session` GenServer.
    - [ ] Add the `Session` GenServer to the supervision tree.
- [ ] **Terminal Integration:**
    - [ ] Integrate `TioComodo` into the `Session` GenServer to handle user input and output.
    - [ ] Implement a basic REPL loop within the `Session` GenServer.
- [ ] **Command Parser:**
    - [ ] Create the `OpenDevCoach.CommandParser` module.
    - [ ] Implement the `parse/1` function to handle basic command structures.
- [ ] **Initial Commands:**
    - [ ] Implement the `/help` command to display a static list of available commands.
    - [ ] Implement the `/quit` and `/exit` commands to gracefully terminate the application.

## Pull Request 3: Task Management Feature

**Goal:** Implement the full suite of task management commands.

- [ ] **Ecto Context:**
    - [ ] Create the `OpenDevCoach.Tasks` context module.
    - [ ] Implement `list_tasks/0`.
    - [ ] Implement `add_task/1`.
    - [ ] Implement `get_task/1`.
    - [ ] Implement `update_task_status/2`.
    - [ ] Implement `remove_task/1`.
- [ ] **Command Integration:**
    - [ ] Integrate `Tasks.add_task/1` with the `/task add` command in the `Session` GenServer.
    - [ ] Integrate `Tasks.list_tasks/0` with the `/task list` command.
    - [ ] Implement the logic for `/task start` to mark a task as `IN-PROGRESS` and others as `ON-HOLD`.
    - [ ] Integrate `Tasks.update_task_status/2` for the `/task complete` command.
    - [ ] Integrate `Tasks.remove_task/1` with the `/task remove` command.
- [ ] **Backup Feature:**
    - [ ] Implement the `/task backup` command to write tasks to a Markdown file.

## Pull Request 4: Configuration Management Feature

**Goal:** Allow users to configure the application, especially for AI settings.

- [ ] **Ecto Context:**
    - [ ] Create the `OpenDevCoach.Configuration` context module.
    - [ ] Implement `get_config/1`, `set_config/2`, `list_configs/0`, and `reset_config/0`.
- [ ] **Command Integration:**
    - [ ] Integrate the context functions with the corresponding `/config` subcommands (`set`, `get`, `list`, `reset`) in the `Session` GenServer.
- [ ] **Gitignore:**
    - [ ] Ensure the SQLite database file is added to `.gitignore` to protect sensitive configurations like API keys.

## Pull Request 5: AI Provider Abstraction & Integration

**Goal:** Create a flexible architecture for supporting multiple AI providers and integrate it into the REPL.

- [ ] **AI Provider Behaviour:**
    - [ ] Define the `OpenDevCoach.AI.Provider` behaviour with a `chat/2` function specification.
- [ ] **AI Factory Module:**
    - [ ] Create the `OpenDevCoach.AI` factory module.
    - [ ] Implement a function that reads the `ai_provider` from config and calls the correct provider module.
- [ ] **Provider Implementations:**
    - [ ] Add `req` and `jason` to `mix.exs` and run `mix deps.get`.
    - [ ] Create the directory `lib/open_dev_coach/ai/providers/`.
    - [ ] Implement the `OpenDevCoach.AI.Providers.Gemini` module, conforming to the `Provider` behaviour.
    - [ ] Implement the `OpenDevCoach.AI.Providers.OpenAI` module.
    - [ ] Implement the `OpenDevCoach.AI.Providers.Anthropic` module.
    - [ ] Implement the `OpenDevCoach.AI.Providers.Ollama` module.
- [ ] **REPL Integration:**
    - [ ] In the `Session` GenServer, handle non-command input by sending it to `OpenDevCoach.AI.chat/2`.
    - [ ] Store the conversation history in the `agent_history` table.
    - [ ] Implement the `/config test` command.

## Pull Request 6: Scheduler & Check-in Management

**Goal:** Add proactive check-ins by implementing a scheduler and the `/checkin` commands.

- [ ] **Scheduler GenServer:**
    - [ ] Create the `OpenDevCoach.Scheduler` GenServer.
    - [ ] Add the `Scheduler` to the supervision tree.
- [ ] **Scheduling Logic:**
    - [ ] Implement logic within the `Scheduler` to use `Process.send_after/3` to trigger check-ins.
    - [ ] The `Scheduler` should send a `:checkin` message to the `Session` process.
- [ ] **Command Integration:**
    - [ ] Implement the `/checkin add` command, including parsing for `HH:MM` and interval formats.
    - [ ] Implement the `/checkin list`, `/checkin remove`, and `/checkin status` commands.
- [ ] **Check-in Handling:**
    - [ ] Implement the `handle_info(:checkin, state)` callback in the `Session` GenServer.
    - [ ] In the callback, gather context (tasks, history) and send it to the AI.
    - [ ] Display the AI's response in the terminal.

## Pull Request 7: Desktop Notifications & Final Polish

**Goal:** Add desktop notifications for check-ins and improve the overall user experience.

- [ ] **Notifier Module:**
    - [ ] Create the `OpenDevCoach.Notifier` module.
    - [ ] Implement a `notify/2` function that detects the OS.
    - [ ] Use `System.cmd/3` to call `notify-send` on Linux and `terminal-notifier` on macOS.
- [ ] **Integration:**
    - [ ] Call `Notifier.notify/2` from the `Session`'s `:checkin` handler.
- [ ] **UI/UX Enhancements:**
    - [ ] Use `TioComodo` features to add color and better formatting to output.
    - [ ] Add a spinner or loading message for AI calls.
- [ ] **Prompt Engineering:**
    - [ ] Develop and refine the system prompt for check-ins to guide the AI to be a helpful coach.
- [ ] **Testing & Documentation:**
    - [ ] Write ExUnit tests for key modules (`CommandParser`, Ecto contexts).
    - [ ] Update the `README.md` with full setup and usage instructions.
    - [ ] Add `@moduledoc` and `@doc` annotations to the code.
