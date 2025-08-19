import Config

# Configure your database
config :open_dev_coach, OpenDevCoach.Repo,
  database: Path.expand("../open_dev_coach_dev.db", Path.dirname(__ENV__.file)),
  pool_size: 5

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"
