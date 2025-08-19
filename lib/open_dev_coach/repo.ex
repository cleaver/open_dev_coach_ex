defmodule OpenDevCoach.Repo do
  use Ecto.Repo,
    otp_app: :open_dev_coach,
    adapter: Ecto.Adapters.SQLite3
end
