defmodule OpenDevCoach.Helpers.Future do
  def future(task, description) when is_atom(task) do
    future(Atom.to_string(task), description)
  end

  def future(task, description) do
    Logger.info("Future task: in #{task} do: #{description}")
  end
end
