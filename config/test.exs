import Config

config :open_dev_coach, OpenDevCoach.Repo,
  database: Path.expand("../open_dev_coach_test.db", Path.dirname(__ENV__.file)),
  pool: Ecto.Adapters.SQL.Sandbox

config :open_dev_coach,
  ecto_repos: [OpenDevCoach.Repo]

# Print only warnings and errors during test
config :logger, level: :warning
