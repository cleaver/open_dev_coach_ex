defmodule OpenDevCoach.Configuration.Config do
  @moduledoc """
  Schema for configuration entries in the OpenDevCoach application.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "configurations" do
    field(:key, :string)
    field(:value, :string)

    timestamps()
  end

  @doc false
  def changeset(config, attrs) do
    config
    |> cast(attrs, [:key, :value])
    |> validate_required([:key, :value])
    |> validate_length(:key, min: 1, max: 100)
    |> validate_length(:value, min: 1, max: 10000)
    |> unique_constraint(:key)
  end
end
