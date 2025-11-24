defmodule OpenDevCoach.Helpers.Changeset do
  @moduledoc """
  Helper functions for working with Ecto changesets.
  """

  @doc """
  Formats changeset errors into a human-readable string.

  Takes an Ecto changeset and returns a comma-separated string of all validation errors.
  """
  def format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map_join(", ", fn {_field, errors} ->
      Enum.join(errors, ", ")
    end)
  end
end
