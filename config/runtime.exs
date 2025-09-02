import Config

log_level_env_var =
  System.get_env("LOG_LEVEL", nil)

if log_level_env_var do
  log_level =
    log_level_env_var
    |> String.downcase()
    |> String.to_existing_atom()

  config :logger, level: log_level
end
