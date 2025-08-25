import Config

# Configure your database
config :open_dev_coach, OpenDevCoach.Repo,
  database: Path.expand("../open_dev_coach.db", Path.dirname(__ENV__.file)),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5")

# Configure Ecto
config :open_dev_coach,
  ecto_repos: [OpenDevCoach.Repo]

# Configure TioComodo REPL
config :tio_comodo,
  simple_provider: {OpenDevCoach.CLI.Commands, :commands}

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
