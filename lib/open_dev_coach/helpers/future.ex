defmodule OpenDevCoach.Helpers.Future do
  @moduledoc """
  Helper module for future tasks.
  """

  require Logger

  @doc """
  Future task.
  """
  @spec future(atom() | String.t(), String.t()) :: :ok
  def future(task, description) when is_atom(task) do
    future(Atom.to_string(task), description)
  end

  def future(task, description) do
    Logger.info("Future task: in #{task} do: #{description}")
  end
end
