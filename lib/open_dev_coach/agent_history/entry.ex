defmodule OpenDevCoach.AgentHistory.Entry do
  @moduledoc """
  Schema for agent history entries in the OpenDevCoach application.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t() :: %__MODULE__{
          id: integer(),
          role: String.t(),
          content: String.t(),
          timestamp: DateTime.t()
        }

  @required_fields [:id, :role, :content, :timestamp]

  schema "agent_history" do
    field(:role, :string)
    field(:content, :string)
    field(:timestamp, :utc_datetime)

    timestamps()
  end

  @doc false
  def changeset(entry, attrs) do
    entry
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:role, ["user", "assistant", "system"])
    |> validate_length(:content, min: 1, max: 10_000)
  end
end
