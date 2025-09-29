defmodule OpenDevCoach.Ai.ModelValidator do
  @moduledoc """
  Validates AI providers and models using the ReqLLM registry.
  """

  @doc """
  Validates that a provider exists in the ReqLLM registry.

  ## Examples

      iex> OpenDevCoach.Ai.ModelValidator.validate_provider("anthropic")
      true

      iex> OpenDevCoach.Ai.ModelValidator.validate_provider("invalid")
      false
  """
  @spec validate_provider(String.t() | atom()) :: boolean()
  def validate_provider(provider_name) when is_binary(provider_name) do
    provider_atom = String.to_atom(provider_name)
    validate_provider(provider_atom)
  end

  def validate_provider(provider_atom) when is_atom(provider_atom) do
    case ReqLLM.Provider.Registry.get_provider(provider_atom) do
      {:ok, _} -> true
      {:error, :not_found} -> false
    end
  end

  @doc """
  Validates that a model specification exists in the ReqLLM registry.

  Accepts various model specification formats:
  - String: "anthropic:claude-3-sonnet"
  - Model struct: %ReqLLM.Model{...}
  - Tuple: {:anthropic, "claude-3-sonnet"}

  ## Examples

      iex> OpenDevCoach.Ai.ModelValidator.validate_model("anthropic:claude-3-sonnet")
      true

      iex> OpenDevCoach.Ai.ModelValidator.validate_model("invalid:model")
      false
  """
  @spec validate_model(String.t() | ReqLLM.Model.t() | {atom(), String.t()}) :: boolean()
  def validate_model(model_spec) do
    case ReqLLM.Model.from(model_spec) do
      {:ok, model} ->
        ReqLLM.Provider.Registry.model_exists?("#{model.provider}:#{model.model}")

      {:error, _} ->
        false
    end
  end
end
