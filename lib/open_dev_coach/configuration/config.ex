defmodule OpenDevCoach.Configuration.Config do
  @moduledoc """
  Schema for configuration entries in the OpenDevCoach application.
  """

  use Ecto.Schema
  import Ecto.Changeset

  # Valid configuration keys
  @valid_keys ["ai_provider", "ai_model", "ai_api_key"]

  schema "configurations" do
    field(:key, :string)
    field(:value, :string)

    timestamps()
  end

  @doc """
  Returns the list of valid configuration keys.
  """
  def valid_keys do
    @valid_keys
  end

  @doc false
  def changeset(config, attrs) do
    config
    |> cast(attrs, [:key, :value])
    |> validate_required([:key, :value])
    |> validate_length(:key, min: 1, max: 100)
    |> validate_length(:value, min: 1, max: 10_000)
    |> validate_inclusion(:key, @valid_keys,
      message: "Invalid configuration key. Valid keys are: #{Enum.join(@valid_keys, ", ")}"
    )
    |> unique_constraint(:key)
  end
end
