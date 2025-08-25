defmodule OpenDevCoach.MixProject do
  use Mix.Project

  def project do
    [
      app: :open_dev_coach,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {OpenDevCoach.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:tio_comodo, "~> 0.1.1"},
      {:ecto, "~> 3.10"},
      {:ecto_sqlite3, "~> 0.12"},
      {:req, "~> 0.4"},
      {:jason, "~> 1.4"},
      {:tzdata, "~> 1.1"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
