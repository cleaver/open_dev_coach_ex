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

    # Build children list conditionally
    children =
      [
        OpenDevCoach.Repo,
        OpenDevCoach.Servers.Session,
        OpenDevCoach.Scheduler
      ] ++
        maybe_start_repl(parent)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: OpenDevCoach.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp maybe_start_repl(parent) do
    iex_running? = Code.ensure_loaded?(IEx) and IEx.started?()
    mix_env_test? = Code.ensure_loaded?(Mix) and Mix.env() == :test

    if mix_env_test? or iex_running? do
      []
    else
      [
        {TioComodo.Repl.Server, prompt: "opendevcoach> ", name: OpenDevCoach.Repl, parent: parent}
      ]
    end
  end
end
