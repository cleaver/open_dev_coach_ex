import Config

# Configure your database
config :open_dev_coach, OpenDevCoach.Repo,
  database: Path.expand("../open_dev_coach_test.db", Path.dirname(__ENV__.file)),
  pool_size: 1

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :open_dev_coach, :test, ecto_repos: [OpenDevCoach.Repo]

# Print only warnings and errors during test
config :logger, level: :warning
