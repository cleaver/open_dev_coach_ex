import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :open_dev_coach, OpenDevCoach.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "odc_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :open_dev_coach,
  async_persistence: false,
  notifications_enabled: false

config :logger,
  backends: [{LoggerFileBackend, :file_log}]

config :logger, :file_log,
  path: "log/odc.test.log",
  level: :debug
