defmodule OpenDevCoach.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # This process waits for the REPL to terminate, then stops the entire VM.
    parent =
      spawn_link(fn ->
        receive do
          :repl_terminated -> :init.stop()
        end
      end)

    children = [
      # Start the Ecto repository
      OpenDevCoach.Repo,
      # Start the main session GenServer
      OpenDevCoach.Session,
      # Start the TioComodo REPL server
      {TioComodo.Repl.Server, prompt: "opendevcoach> ", name: OpenDevCoach.Repl, parent: parent}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: OpenDevCoach.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
