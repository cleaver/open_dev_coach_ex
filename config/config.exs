import Config

# Configure your database
config :open_dev_coach, OpenDevCoach.Repo,
  database: Path.expand("../open_dev_coach.db", Path.dirname(__ENV__.file))

# Set a default pool size for non-test environments.
# This is explicitly not set for the :test environment because it conflicts
# with the Ecto Sandbox pool.
if Mix.env() != :test do
  config :open_dev_coach, OpenDevCoach.Repo,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5")
end

# Configure Ecto
config :open_dev_coach,
  ecto_repos: [OpenDevCoach.Repo],
  async_persistence: true,
  notifications_enabled: true

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
