defmodule OpenDevCoach.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    maybe_set_test_ai_option()

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
        OpenDevCoach.Servers.Scheduler
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

  defp maybe_set_test_ai_option do
    if "--testai" in System.argv() do
      Application.put_env(:open_dev_coach, :test_ai, true)
    end
  end
end
