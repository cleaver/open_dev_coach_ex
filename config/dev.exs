import Config

# Configure your database
config :open_dev_coach, OpenDevCoach.Repo,
  database: Path.expand("../open_dev_coach.db", Path.dirname(__ENV__.file)),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5")

# Configure timezone for development
config :open_dev_coach,
  timezone: "America/New_York"

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"
