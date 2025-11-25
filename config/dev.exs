import Config

# Configure your database
config :open_dev_coach, OpenDevCoach.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "odc_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

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
