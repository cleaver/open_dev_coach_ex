defmodule OpenDevCoach.AI do
  @moduledoc """
  AI factory module for OpenDevCoach.

  This module acts as the main entry point for AI interactions,
  using the ReqLLM library to communicate with various providers.
  """

  require Logger

  import OpenDevCoach.Helpers.Future

  alias OpenDevCoach.Ai.ModelValidator
  alias OpenDevCoach.Configuration

  @doc """
  Sends a chat message to the configured AI provider.

  ## Parameters
    - messages: List of message maps with :role and :content keys
    - opts: Keyword list of additional options, including :tools for tool calls.

  ## Returns
    - `{:ok, %{text: response_text, tool_calls: tool_calls}}` on success
    - `{:error, error_message}` on failure

  ## Example
      iex> messages = [%{role: "user", content: "Hello, how are you?"}]
      iex> OpenDevCoach.AI.chat(messages)
      {:ok, %{text: "Hello! I'm doing well, thank you for asking.", tool_calls: []}}
  """
  def chat(messages, opts \\ []) do
    case get_ai_config(opts) do
      {:ok, config} ->
        if Application.get_env(:open_dev_coach, :test_ai, false) do
          Logger.info("Logging AI prompt to log/ai_prompts.log (test mode enabled)")
          log_ai_prompt(messages, opts)

          {:ok,
           %{text: "AI prompt logged to log/ai_prompts.log (test mode enabled)", tool_calls: []}}
        else
          Logger.info("Sending AI prompt to #{config["ai_provider"]}")
          provider = Map.get(config, "ai_provider")
          api_key = Map.get(config, "ai_api_key")
          model_name = Map.get(config, "ai_model")

          model_spec = "#{provider}:#{model_name}"

          provider_atom = String.to_atom(provider)
          config_key = ReqLLM.Keys.config_key(provider_atom)
          ReqLLM.put_key(config_key, api_key)

          future("OpenDevCoach.AI.chat/2", "Set ReqLLM.generate_text options")

          case ReqLLM.generate_text(model_spec, messages) do
            {:ok, response} ->
              text = ReqLLM.Response.text(response)
              tool_calls = response.message.content |> Enum.filter(&(&1.type == :tool_call))
              {:ok, %{text: text, tool_calls: tool_calls}}

            {:error, reason} ->
              Logger.error("ReqLLM error: #{inspect(reason)}")
              {:error, "ReqLLM error: #{inspect(reason)}"}
          end
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_ai_config(opts) do
    config = Keyword.get(opts, :config, %{})

    with {:ok, provider} <- get_ai_provider(config),
         {:ok, model} <- get_ai_model(config, provider),
         {:ok, api_key} <- get_ai_api_key(config) do
      complete_config = %{
        "ai_provider" => provider,
        "ai_model" => model,
        "ai_api_key" => api_key
      }

      {:ok, complete_config}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_ai_provider(config) when is_map_key(config, "ai_provider") do
    Map.get(config, "ai_provider")
    |> validate_ai_provider()
  end

  defp get_ai_provider(_config) do
    Configuration.get_config("ai_provider")
    |> validate_ai_provider()
  end

  defp validate_ai_provider(provider) do
    if ModelValidator.validate_provider(provider) do
      {:ok, provider}
    else
      {:error, "Unknown or unsupported AI provider: #{provider}"}
    end
  end

  defp get_ai_model(config, provider) when is_map_key(config, "ai_model") do
    Map.get(config, "ai_model")
    |> validate_ai_model(provider)
  end

  defp get_ai_model(_config, provider) do
    Configuration.get_config("ai_model")
    |> validate_ai_model(provider)
  end

  defp validate_ai_model(value, provider) do
    model_spec = "#{provider}:#{value}"

    if ModelValidator.validate_model(model_spec) do
      {:ok, model_spec}
    else
      {:error, "Unknown or unsupported AI model: #{model_spec}"}
    end
  end

  defp get_ai_api_key(config) do
    case Map.get(config, "ai_api_key") do
      nil ->
        Configuration.get_config("ai_api_key")
        |> validate_ai_api_key()

      value ->
        {:ok, value}
    end
  end

  defp validate_ai_api_key(value) do
    if is_binary(value) and String.length(value) > 0 do
      {:ok, value}
    else
      {:error, "Missing required AI configuration key: ai_api_key"}
    end
  end

  @doc """
  Gets the currently configured AI provider name for ReqLLM.

  ## Returns
    - `{:ok, provider_name}` (e.g., "google") or `{:error, reason}`
  """
  def get_configured_provider_name do
    provider = Configuration.get_config("ai_provider")

    if is_nil(provider) do
      {:error, "No AI provider configured. Set it with `/config set ai_provider gemini`"}
    else
      available_providers = ModelValidator.list_providers()
      provider_atom = String.to_atom(provider)

      if provider_atom in available_providers do
        {:ok, provider}
      else
        {:error, "Unknown or unsupported AI provider: #{provider}"}
      end
    end
  end

  @doc """
  Tests the current AI configuration by sending a simple message. Optionally provide a config map.

  ## Returns
    - `{:ok, "Test successful: <response>"}` on success
    - `{:error, error_message}` on failure
  """
  def test_configuration(config \\ nil) do
    messages = [%{role: "user", content: "Hello! Please respond with a brief greeting."}]

    case chat(messages, config: config) do
      {:ok, %{text: response}} when is_binary(response) ->
        {:ok, "Test successful: #{response}"}

      {:error, reason} ->
        {:error, "Test failed: #{reason}"}
    end
  end

  # Private function to log AI prompts when in test mode
  defp log_ai_prompt(messages, opts) do
    # Ensure log directory exists
    log_dir = "log"
    File.mkdir_p!(log_dir)

    # Create the log entry with timestamp and full JSON
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

    # Convert opts to a JSON-serializable format
    serializable_opts = convert_opts_to_serializable(opts)

    log_entry = %{
      timestamp: timestamp,
      messages: messages,
      options: serializable_opts
    }

    # Convert to JSON and append to file
    json_data = Jason.encode!(log_entry, pretty: true)
    log_line = "#{timestamp}\n#{json_data}\n\n"

    # Append to the log file
    File.write!("log/ai_prompts.log", log_line, [:append])
  end

  # Convert keyword list options to a JSON-serializable format
  defp convert_opts_to_serializable(opts) when is_list(opts) do
    Enum.map(opts, fn
      {key, value} when is_atom(key) ->
        {Atom.to_string(key), convert_value_to_serializable(value)}

      {key, value} ->
        {to_string(key), convert_value_to_serializable(value)}
    end)
    |> Enum.into(%{})
  end

  # Convert individual values to JSON-serializable format
  defp convert_value_to_serializable(value) when is_tuple(value) do
    # Convert tuples to maps with type information
    case value do
      {:context, context_value} ->
        %{"type" => "context", "value" => context_value}

      {key, val} ->
        %{
          "type" => "tuple",
          "key" => to_string(key),
          "value" => convert_value_to_serializable(val)
        }

      _ ->
        %{
          "type" => "tuple",
          "value" => Tuple.to_list(value) |> Enum.map(&convert_value_to_serializable/1)
        }
    end
  end

  defp convert_value_to_serializable(value) when is_list(value) do
    Enum.map(value, &convert_value_to_serializable/1)
  end

  defp convert_value_to_serializable(value) when is_map(value) do
    Map.new(value, fn {k, v} -> {to_string(k), convert_value_to_serializable(v)} end)
  end

  defp convert_value_to_serializable(value) when is_atom(value) do
    Atom.to_string(value)
  end

  defp convert_value_to_serializable(value) do
    value
  end
end
