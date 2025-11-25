import Config

config :open_dev_coach, OpenDevCoach.Repo,
  database: "open_dev_coach_repo",
  username: "user",
  password: "pass",
  hostname: "localhost"

# Configure Ecto
config :open_dev_coach,
  ecto_repos: [OpenDevCoach.Repo],
  async_persistence: true,
  notifications_enabled: true,
  generators: [timestamp_type: :utc_datetime]

# Configure timezone (default to America/New_York, can be overridden in environment configs)
config :open_dev_coach,
  timezone: "America/New_York"

# Configure TioComodo REPL
config :tio_comodo,
  simple_provider: {OpenDevCoach.CLI.Commands, :commands}

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
