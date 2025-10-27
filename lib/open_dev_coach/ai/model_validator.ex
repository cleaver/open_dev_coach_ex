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
      {:error, _} -> false
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

  @doc """
  Returns a list of all available provider:model combinations from the ReqLLM registry.

  ## Options
  - `:provider` - Filter by specific provider (atom or string)
  - `:with_tool_calls` - If true, only return models that support tool calls (default: false)
  - `:format` - Output format: `:string` (default) or `:model_struct`

  ## Examples

      iex> OpenDevCoach.Ai.ModelValidator.list_all_models()
      ["anthropic:claude-3-haiku-20240307", "openai:gpt-4o", ...]

      iex> OpenDevCoach.Ai.ModelValidator.list_all_models(provider: :anthropic)
      ["anthropic:claude-3-haiku-20240307", "anthropic:claude-3-sonnet-20240229", ...]

      iex> OpenDevCoach.Ai.ModelValidator.list_all_models(with_tool_calls: true)
      ["anthropic:claude-3-sonnet-20240229", "openai:gpt-4o", ...]

      iex> OpenDevCoach.Ai.ModelValidator.list_all_models(format: :model_struct)
      [%ReqLLM.Model{provider: :anthropic, model: "claude-3-haiku-20240307", ...}, ...]
  """
  @spec list_all_models(keyword()) :: [String.t()] | [ReqLLM.Model.t()]
  def list_all_models(opts \\ []) do
    format = Keyword.get(opts, :format, :string)
    provider_filter = Keyword.get(opts, :provider)
    with_tool_calls = Keyword.get(opts, :with_tool_calls, false)

    # Get all providers
    providers = list_providers()

    # Get all models from all providers
    all_models =
      providers
      |> Enum.flat_map(&get_models_for_provider/1)
      |> apply_filters(provider_filter, with_tool_calls)
      |> format_output(format)

    all_models
  end

  @doc """
  Returns a list of all available providers in the ReqLLM registry.

  ## Examples

      iex> OpenDevCoach.Ai.ModelValidator.list_providers()
      [:anthropic, :openai, :google, :groq, :xai, :openrouter]
  """
  @spec list_providers() :: [atom()]
  def list_providers do
    # Try to get providers from ReqLLM's registry
    case get_providers_from_registry() do
      {:ok, providers} -> providers
      {:error, _} -> get_providers_from_metadata()
    end
  end

  @doc """
  Returns models for a specific provider.

  ## Examples

      iex> OpenDevCoach.Ai.ModelValidator.list_models_for_provider(:anthropic)
      ["anthropic:claude-3-haiku-20240307", "anthropic:claude-3-sonnet-20240229", ...]

      iex> OpenDevCoach.Ai.ModelValidator.list_models_for_provider("openai")
      ["openai:gpt-4o", "openai:gpt-4o-mini", ...]
  """
  @spec list_models_for_provider(atom() | String.t()) :: [String.t()]
  def list_models_for_provider(provider) when is_binary(provider) do
    provider_atom = String.to_atom(provider)
    list_models_for_provider(provider_atom)
  end

  def list_models_for_provider(provider_atom) when is_atom(provider_atom) do
    get_models_for_provider(provider_atom)
  end

  # Private helper functions

  defp get_providers_from_registry do
    # Try to get providers from ReqLLM's Provider.Registry
    # This is a best-effort approach since ReqLLM doesn't expose a direct list function
    case Code.ensure_loaded?(ReqLLM.Provider.Registry) do
      true ->
        # Try to discover providers by checking common ones
        common_providers = [:anthropic, :openai, :google, :groq, :xai, :openrouter]
        valid_providers = Enum.filter(common_providers, &validate_provider/1)
        {:ok, valid_providers}

      false ->
        {:error, :not_loaded}
    end
  end

  defp get_providers_from_metadata do
    # Fallback: try to read from ReqLLM's metadata files
    case read_metadata_files() do
      {:ok, providers} -> providers
      {:error, _} -> []
    end
  end

  defp read_metadata_files do
    # Try to read from ReqLLM's priv/models_dev/ directory
    # This is a fallback method that reads the JSON metadata files
    case File.ls("deps/req_llm/priv/models_dev/") do
      {:ok, files} ->
        providers =
          files
          |> Enum.filter(&String.ends_with?(&1, ".json"))
          |> Enum.map(&String.replace_suffix(&1, ".json", ""))
          |> Enum.map(&String.to_atom/1)
          |> Enum.filter(&validate_provider/1)

        {:ok, providers}

      {:error, _} ->
        {:error, :metadata_not_found}
    end
  end

  defp get_models_for_provider(provider_atom) do
    # Try to read models from ReqLLM's metadata files
    provider_string = Atom.to_string(provider_atom)
    metadata_file = "deps/req_llm/priv/models_dev/#{provider_string}.json"

    case File.read(metadata_file) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, %{"models" => models}} ->
            models
            |> Enum.map(fn model -> "#{provider_string}:#{model["id"]}" end)
            |> Enum.filter(&validate_model/1)

          {:error, _} ->
            []
        end

      {:error, _} ->
        []
    end
  end

  defp apply_filters(models, provider_filter, with_tool_calls) do
    models
    |> filter_by_provider(provider_filter)
    |> filter_by_tool_calls(with_tool_calls)
  end

  defp filter_by_provider(models, nil), do: models

  defp filter_by_provider(models, provider_filter) when is_atom(provider_filter) do
    provider_string = Atom.to_string(provider_filter)
    Enum.filter(models, &String.starts_with?(&1, "#{provider_string}:"))
  end

  defp filter_by_provider(models, provider_filter) when is_binary(provider_filter) do
    Enum.filter(models, &String.starts_with?(&1, "#{provider_filter}:"))
  end

  defp filter_by_tool_calls(models, false), do: models

  defp filter_by_tool_calls(models, true) do
    # Filter models to only those that support tool calls
    Enum.filter(models, fn model_string ->
      case ReqLLM.Model.from(model_string) do
        {:ok, model} ->
          Map.get(model.capabilities, :tool_call, false) == true

        {:error, _} ->
          false
      end
    end)
  end

  defp format_output(models, :string), do: models

  defp format_output(models, :model_struct) do
    Enum.map(models, fn model_string ->
      case ReqLLM.Model.from(model_string) do
        {:ok, model} -> model
        {:error, _} -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end
end
