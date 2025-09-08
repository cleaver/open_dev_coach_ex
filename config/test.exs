import Config

config :open_dev_coach, OpenDevCoach.Repo,
  database: Path.expand("../open_dev_coach_test.db", Path.dirname(__ENV__.file)),
  pool: Ecto.Adapters.SQL.Sandbox

config :open_dev_coach,
  ecto_repos: [OpenDevCoach.Repo]

config :logger,
  backends: [{LoggerFileBackend, :file_log}]

config :logger, :file_log,
  path: "log/odc.test.log",
  level: :debug
