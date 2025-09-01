# OpenDevCoach

A terminal-based AI productivity coach to help you stay on task.

## Architecture Overview

The application's core logic is managed by two primary GenServers that follow the Single Responsibility Principle:

*   `OpenDevCoach.Session`: This GenServer acts as the central orchestrator for application logic. It manages state for tasks, configuration, and handles all interactions with the AI provider. It answers the question "what happens."

*   `OpenDevCoach.Scheduler`: This GenServer is responsible for all time-based events. It manages the lifecycle of scheduled check-ins, persisting them to the database and using `Process.send_after` to trigger them at the correct time. It answers the question "when things happen."

When a scheduled check-in time arrives, the `Scheduler` sends a message to the `Session`, which then executes the check-in logic. This separation keeps the core application logic decoupled from the time-scheduling mechanism.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `open_dev_coach` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:open_dev_coach, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/open_dev_coach>.

