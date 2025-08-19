# Open Dev Coach - Implementation Plan

## Project Overview

A personal developer productivity application built in Elixir that acts as an intelligent development coach. The app provides task management, scheduled check-ins, AI integration across multiple providers, and persistent progress tracking through an agentic loop system.

## Core Architecture

### 1. Application Structure
```
lib/
├── open_dev_coach/
│   ├── application.ex (main supervisor)
│   ├── cli/
│   │   ├── interface.ex (main CLI loop using tio_comodo)
│   │   ├── command_parser.ex (parse user commands)
│   │   └── command_handler.ex (execute commands)
│   ├── ai/
│   │   ├── provider_behaviour.ex (AI provider interface)
│   │   ├── providers/
│   │   │   ├── openai.ex
│   │   │   ├── gemini.ex
│   │   │   ├── anthropic.ex
│   │   │   └── ollama.ex
│   │   └── manager.ex (provider selection/routing)
│   ├── data/
│   │   ├── repo.ex (Ecto repository)
│   │   ├── schemas/
│   │   │   ├── task.ex
│   │   │   ├── checkin.ex
│   │   │   ├── agent_history.ex
│   │   │   └── config.ex
│   │   └── migrations/
│   ├── agent/
│   │   ├── history.ex (track agent interactions)
│   │   ├── context.ex (manage current context)
│   │   └── loop.ex (main agentic loop)
│   ├── tasks/
│   │   ├── manager.ex (task CRUD operations)
│   │   └── backup.ex (markdown export)
│   ├── checkins/
│   │   ├── scheduler.ex (GenServer for scheduling)
│   │   ├── manager.ex (checkin CRUD)
│   │   └── processor.ex (handle checkin logic)
│   ├── config/
│   │   └── manager.ex (configuration management)
│   └── notifications/
│       └── system.ex (desktop notifications)
└── open_dev_coach.ex (main entry point)
```

## Implementation Phases

### Phase 1: Foundation (High Priority)
**Goal**: Basic infrastructure and data persistence

#### 1.1 Database Setup
- [ ] Add Ecto and SQLite dependencies to `mix.exs`
- [ ] Create `OpenDevCoach.Repo` module
- [ ] Create database schemas:
  - [ ] `Task` schema (id, description, status, created_at, updated_at, started_at, completed_at)
  - [ ] `Checkin` schema (id, scheduled_time, type, is_active, created_at)
  - [ ] `AgentHistory` schema (id, type, content, metadata, inserted_at)
  - [ ] `Config` schema (key, value, inserted_at, updated_at)
- [ ] Create and run initial migrations
- [ ] Update Application supervisor to include Repo

#### 1.2 Configuration Management
- [ ] Implement `OpenDevCoach.Config.Manager`
- [ ] Support for setting/getting config values
- [ ] Default configuration values
- [ ] Configuration validation
- [ ] Database persistence for config

#### 1.3 Task Management Core
- [ ] Implement `OpenDevCoach.Tasks.Manager`
- [ ] CRUD operations for tasks
- [ ] Task status management (PENDING, IN-PROGRESS, ON-HOLD, COMPLETED)
- [ ] Business logic for status transitions
- [ ] Only allow one IN-PROGRESS task at a time

### Phase 2: CLI Interface (High Priority)
**Goal**: Interactive terminal interface with command parsing

#### 2.1 Basic CLI Framework
- [ ] Implement `OpenDevCoach.CLI.Interface` using `tio_comodo`
- [ ] Main application loop
- [ ] Command input/output handling
- [ ] Graceful exit handling

#### 2.2 Command System
- [ ] Implement `OpenDevCoach.CLI.CommandParser`
- [ ] Parse commands with arguments
- [ ] Support for `/help`, `/quit`, `/exit`
- [ ] Implement `OpenDevCoach.CLI.CommandHandler`
- [ ] Route commands to appropriate modules

#### 2.3 Task Commands
- [ ] `/task add <description>` - Add new task
- [ ] `/task list` - Show all tasks with status
- [ ] `/task start <number>` - Start task (set others to ON-HOLD)
- [ ] `/task complete <number>` - Complete task
- [ ] `/task remove <number>` - Remove task
- [ ] `/task backup` - Export tasks as markdown

#### 2.4 Config Commands
- [ ] `/config set <key> <value>` - Set configuration
- [ ] `/config get <key>` - Get configuration
- [ ] `/config list` - List all config
- [ ] `/config reset` - Reset to defaults
- [ ] `/config test` - Test AI connection
- [ ] `/config status` - Check AI service status

### Phase 3: AI Integration (High Priority)
**Goal**: Multi-provider AI integration with tool calling support

#### 3.1 AI Provider Architecture
- [ ] Define `OpenDevCoach.AI.ProviderBehaviour`
- [ ] Common interface for all providers
- [ ] Support for chat completions and tool calling
- [ ] Error handling and rate limiting

#### 3.2 AI Provider Implementations
- [ ] `OpenDevCoach.AI.Providers.OpenAI`
  - [ ] HTTP client setup
  - [ ] Chat completions API
  - [ ] Tool calling support
  - [ ] Error handling
- [ ] `OpenDevCoach.AI.Providers.Gemini`
  - [ ] Google AI Studio API integration
  - [ ] Function calling support
- [ ] `OpenDevCoach.AI.Providers.Anthropic`
  - [ ] Claude API integration
  - [ ] Tool use support
- [ ] `OpenDevCoach.AI.Providers.Ollama`
  - [ ] Local Ollama API integration
  - [ ] Function calling (if supported)

#### 3.3 AI Manager
- [ ] `OpenDevCoach.AI.Manager`
- [ ] Provider selection based on config
- [ ] Fallback provider support
- [ ] Request routing and response handling

### Phase 4: Agent System (Medium Priority)
**Goal**: Agentic loop with history and context management

#### 4.1 Agent History
- [ ] `OpenDevCoach.Agent.History`
- [ ] Track meaningful interactions (not every command)
- [ ] Store task changes and user decisions
- [ ] Retrieve recent history for context

#### 4.2 Agent Context
- [ ] `OpenDevCoach.Agent.Context`
- [ ] Maintain current session state
- [ ] Task list state
- [ ] Recent interactions
- [ ] Configuration state

#### 4.3 Agent Loop
- [ ] `OpenDevCoach.Agent.Loop`
- [ ] Main conversation loop with AI
- [ ] Context injection
- [ ] Response processing
- [ ] Tool calling integration

### Phase 5: Scheduling & Check-ins (Medium Priority)
**Goal**: Automated check-in system with notifications

#### 5.1 Check-in Management
- [ ] `OpenDevCoach.Checkins.Manager`
- [ ] CRUD operations for check-ins
- [ ] Support time format parsing (HH:MM, Xh Ym)
- [ ] Validation and conflict detection

#### 5.2 Scheduler
- [ ] `OpenDevCoach.Checkins.Scheduler` GenServer
- [ ] Schedule check-ins using Process.send_after
- [ ] Handle system restarts and rescheduling
- [ ] Persistent scheduling state

#### 5.3 Check-in Processor
- [ ] `OpenDevCoach.Checkins.Processor`
- [ ] Trigger check-in conversations
- [ ] Gather context (tasks, history, last check-in)
- [ ] AI conversation with check-in focus

#### 5.4 Check-in Commands
- [ ] `/checkin add <time>` - Schedule check-in
- [ ] `/checkin list` - Show scheduled check-ins
- [ ] `/checkin remove <number>` - Remove check-in
- [ ] `/checkin status` - Show scheduler status

### Phase 6: Notifications (Medium Priority)
**Goal**: Desktop notification system

#### 6.1 Notification Research & Implementation
- [ ] Research cross-platform notification options
- [ ] Implement `OpenDevCoach.Notifications.System`
- [ ] macOS: Use `terminal-notifier` or `osascript`
- [ ] Linux: Use `notify-send`
- [ ] Fallback to terminal bell/message
- [ ] Test on both platforms

### Phase 7: Enhanced Features (Low Priority)
**Goal**: Additional developer productivity features

#### 7.1 Advanced Task Features
- [ ] Task priorities (high, medium, low)
- [ ] Task categories/tags
- [ ] Task time estimates
- [ ] Task dependencies
- [ ] Task search and filtering

#### 7.2 Enhanced Agent Features
- [ ] Daily/weekly progress summaries
- [ ] Goal tracking and suggestions
- [ ] Productivity insights
- [ ] Context-aware suggestions

#### 7.3 Data Export/Import
- [ ] Full data backup/restore
- [ ] Integration with external task systems
- [ ] Calendar integration
- [ ] Time tracking integration

#### 7.4 Advanced Scheduling
- [ ] Recurring check-ins
- [ ] Context-aware scheduling
- [ ] Break reminders
- [ ] Focus session timers

## Technical Specifications

### Dependencies to Add
```elixir
# mix.exs
defp deps do
  [
    {:tio_comodo, "~> 0.1.1"},
    {:ecto_sql, "~> 3.10"},
    {:ecto_sqlite3, "~> 0.10"},
    {:jason, "~> 1.4"},
    {:httpoison, "~> 2.0"},
    {:timex, "~> 3.7"},
    {:uuid, "~> 1.1"}
  ]
end
```

### Database Schema Design

#### Tasks Table
```sql
CREATE TABLE tasks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  description TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'PENDING',
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  started_at DATETIME,
  completed_at DATETIME
);
```

#### Check-ins Table
```sql
CREATE TABLE checkins (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  scheduled_time TEXT NOT NULL, -- "HH:MM" format
  type TEXT NOT NULL DEFAULT 'daily', -- daily, interval
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at DATETIME NOT NULL
);
```

#### Agent History Table
```sql
CREATE TABLE agent_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  type TEXT NOT NULL, -- 'task_change', 'checkin', 'conversation'
  content TEXT NOT NULL, -- JSON content
  metadata TEXT, -- Additional JSON metadata
  inserted_at DATETIME NOT NULL
);
```

#### Configuration Table
```sql
CREATE TABLE configs (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  inserted_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL
);
```

### AI Provider Interface
```elixir
defmodule OpenDevCoach.AI.ProviderBehaviour do
  @callback chat_completion(messages :: list(), opts :: keyword()) :: 
    {:ok, response :: map()} | {:error, reason :: term()}
  
  @callback supports_tools?() :: boolean()
  
  @callback available?() :: boolean()
end
```

### Configuration Keys
- `ai_provider`: "openai" | "gemini" | "anthropic" | "ollama"
- `ai_model`: Model name for the provider
- `ai_api_key`: API key for external services
- `ai_base_url`: Base URL for Ollama
- `notification_enabled`: true | false
- `daily_checkin_enabled`: true | false

## Implementation Order & Timeline

### Week 1: Foundation
- Phase 1.1: Database Setup
- Phase 1.2: Configuration Management
- Phase 1.3: Task Management Core

### Week 2: CLI Interface
- Phase 2.1: Basic CLI Framework
- Phase 2.2: Command System
- Phase 2.3: Task Commands
- Phase 2.4: Config Commands

### Week 3: AI Integration
- Phase 3.1: AI Provider Architecture
- Phase 3.2: Provider Implementations (Start with OpenAI)
- Phase 3.3: AI Manager

### Week 4: Agent System
- Phase 4.1: Agent History
- Phase 4.2: Agent Context
- Phase 4.3: Agent Loop

### Week 5: Scheduling & Notifications
- Phase 5: Complete scheduling system
- Phase 6: Notification system

### Week 6+: Enhanced Features
- Phase 7: Additional features based on usage feedback

## Testing Strategy

### Unit Tests
- [ ] Task management operations
- [ ] Configuration management
- [ ] Command parsing
- [ ] AI provider interfaces
- [ ] Database operations

### Integration Tests
- [ ] CLI command flow
- [ ] AI provider integration
- [ ] Database migrations
- [ ] Check-in scheduling

### Manual Testing
- [ ] Cross-platform compatibility (macOS/Linux)
- [ ] Notification systems
- [ ] AI provider connections
- [ ] Full user workflow scenarios

## Risk Mitigation

### Technical Risks
1. **AI Provider Rate Limits**: Implement exponential backoff and fallback providers
2. **Database Corruption**: Regular backups and validation
3. **Cross-platform Issues**: Comprehensive testing on both macOS and Linux
4. **Dependency Issues**: Pin dependency versions and test compatibility

### User Experience Risks
1. **Overwhelming Interface**: Start with minimal features, add incrementally
2. **Performance Issues**: Optimize database queries and AI calls
3. **Notification Fatigue**: Make check-ins configurable and intelligent

## Success Metrics

### MVP Success Criteria
- [ ] Can add, list, start, complete, and remove tasks
- [ ] Can configure AI provider and test connection
- [ ] Can schedule and receive check-ins
- [ ] Can maintain conversation history across sessions
- [ ] Works reliably on both macOS and Linux

### Enhanced Success Criteria
- [ ] User actively uses daily for 1+ weeks
- [ ] Provides valuable productivity insights
- [ ] Integrates smoothly into development workflow
- [ ] Minimal setup required for new users

## Future Considerations

### MCP Integration
The specification mentions Model Context Protocol (MCP) integration for external task/check-in systems. This could be implemented as:
- [ ] MCP client implementation
- [ ] External service integration
- [ ] Plugin architecture for future extensions

### Scalability
While this is a personal tool, consider:
- [ ] Multi-user support (future)
- [ ] Team collaboration features
- [ ] Cloud synchronization
- [ ] Mobile companion app

This plan provides a comprehensive roadmap for building the Open Dev Coach application with clear phases, technical specifications, and success criteria. The modular architecture allows for incremental development and testing while maintaining flexibility for future enhancements.