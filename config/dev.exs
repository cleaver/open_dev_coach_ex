import Config

# Configure your database
config :open_dev_coach, OpenDevCoach.Repo,
  database: Path.expand("../open_dev_coach.db", Path.dirname(__ENV__.file)),
  pool_size: 5,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true

# Configure timezone for development
config :open_dev_coach,
  timezone: "America/New_York",
  test_ai: true

config :logger,
  backends: [{LoggerFileBackend, :file_log}]

config :logger, :file_log,
  path: "log/odc.dev.log",
  level: :debug

# Git hooks
config :git_hooks,
  auto_install: true,
  verbose: true,
  hooks: [
    pre_commit: [
      tasks: [
        {:cmd, "mix format --check-formatted"}
      ]
    ],
    pre_push: [
      verbose: false,
      tasks: [
        {:cmd, "mix dialyzer"},
        {:cmd, "mix test"},
        {:cmd, "mix credo --strict"}
      ]
    ]
  ]
