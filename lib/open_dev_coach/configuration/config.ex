defmodule OpenDevCoach.Configuration.Config do
  @moduledoc """
  Schema for configuration entries in the OpenDevCoach application.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t() :: %__MODULE__{
          id: binary(),
          key: String.t(),
          value: String.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @required_fields [:key, :value]
  @optional_fields [:id]
  @all_fields @required_fields ++ @optional_fields

  @valid_keys ~w(ai_provider ai_model ai_api_key)

  def config_keys, do: @valid_keys

  @primary_key {:id, :binary_id, autogenerate: true}
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
    |> cast(attrs, @all_fields)
    |> validate_required(@required_fields)
    |> validate_length(:key, min: 1, max: 100)
    |> validate_length(:value, min: 1, max: 10_000)
    |> validate_inclusion(:key, @valid_keys,
      message: "Invalid configuration key. Valid keys are: #{Enum.join(@valid_keys, ", ")}"
    )
    |> unique_constraint(:key)
  end
end
