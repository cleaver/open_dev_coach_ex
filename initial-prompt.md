
I want to build a personal developer productivity application that will check what I am doing today and call an AI to discuss plans and timing with me. 

I have created a basic Elixir project with supervision in this directory.

Important features:
- It will be an agentic loop with history of the last few interactions.
- Access to tasks and check-ins will be MCP calls, or internal calls as appropriate. The task and check-in systems could be replaced by an external MCP service in the future.
- It should connect to multiple AI providers starting with OpenAI, Gemini, Anthropic, and local Ollama. There doesn't seem to be a multi-provider library that does tool calls, so we must define our own behaviour and wrap the associated libraries.
- It should save the current days progress in case it needs to restart. 
- It should use the `tio_comodo` terminal i/o library (already added)
- The app is to set scheduled check-in times (time and date) to check in with me on how things are going and to discuss any problems. There would need to be some sort of scheduler for that. 
- When a check-in occurs, the app sends the recent agent history, including any task changes, as well as the current state of the task list and the last check-in output.
- In order to alert me, I want to be able to send notifications. Research what is available to send desktop notifications. If not available, maybe wrap bash commands, or node.js: `terminal-notifier` or `notify-send`. 
- Use SQLite3 database with Ecto.
- This should work on both MacOS and Linux.

## Commands

### Agent History

The agent history doesn't need to track each command and it's output. However, when a user makes a change to a todo item, record the change. EG: `{input: [{role: "user", content: "task marked complete: 'Refactor UserAuthService.js to use async/await and centralize error handling.'"}]}`

### In-App Commands

*   `/help`: Display available commands.
*   `/quit`: Exit the application.
*   `/exit`: (alternate) Exit the application.

#### Task Management (`/task`)
*   `/task add <task description>`: Add a new task.
    *   Example: `/task add Implement AI integration`
*   `/task list`: List all your current tasks.
*   `/task start <task number>`: Mark a task as in progress. Mark the current in-progress tasks as `[ON-HOLD]`.
    *   Example: `/task start 1`
*   `/task complete <task number>`: Mark a task as completed.
    *   Example: `/task complete 1`
*   `/task remove <task number>`: Remove a task.
    *   Example: `/task remove 2`
*   `/task backup`: Create a backup of your tasks as a Markdown checklist.

Task statuses include:
- `[PENDING]` - Added but not yet worked on.
- `[IN-PROGRESS]` - Currently working on. There can only be one.
- `[ON-HOLD]` - put on hold to work on something else.
- `[COMPLETED]` - Done.

#### Configuration (`/config`)
*   `/config set <key> <value>`: Set a configuration value.
    *   Example: `/config set ai_api_key YOUR_GEMINI_API_KEY`
*   `/config get <key>`: Get a configuration value.
    *   Example: `/config get ai_api_key`
*   `/config list`: List all current configuration settings.
*   `/config reset`: Reset all configuration to defaults.
*   `/config test`: Test the AI connection with your current API key.
*   `/config status`: Check the current AI service status.

Config keys include `ai_provider`, `ai_model`, `ai_api_key`.

#### Check-in Management (`/checkin`)
*   `/checkin add <time>`: Schedule a daily check-in time.
    *   **Time format:** `HH:MM` (e.g., `09:30` for 9:30 AM)
    *   **Interval format:** `Xh Ym` (e.g., `2h 30m` for 2 hours 30 minutes from now)
    *   Examples: `/checkin add 09:30`, `/checkin add 2h 30m`, `/checkin add 30m`
    *   Each check-in is assigned a unique ID internally for tracking
*   `/checkin list`: List all scheduled check-in times with their display numbers.
*   `/checkin remove <check-in number>`: Remove a scheduled check-in using the displayed list number.
    *   Example: `/checkin remove 1` (removes the first check-in shown in the list)
*   `/checkin status`: Show the status of scheduled check-ins.

There should be more features than this. Think of a developer's daily workflow and what will be helpful, encouraging, but not too intrusive or overwhelming. Think of building an amazing helpful personal developer coach.

