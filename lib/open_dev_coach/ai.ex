defmodule OpenDevCoach.AI do
  @moduledoc """
  AI factory module for OpenDevCoach.

  This module acts as the main entry point for AI interactions,
  routing requests to the appropriate provider based on configuration.
  """

  alias OpenDevCoach.AI.Providers.Gemini
  alias OpenDevCoach.Configuration

  @doc """
  Sends a chat message to the configured AI provider.

  ## Parameters
    - messages: List of message maps with :role and :content keys
    - opts: Keyword list of additional options

  ## Returns
    - `{:ok, response_text}` on success
    - `{:error, error_message}` on failure

  ## Example
      iex> messages = [%{role: "user", content: "Hello, how are you?"}]
      iex> OpenDevCoach.AI.chat(messages)
      {:ok, "Hello! I'm doing well, thank you for asking."}
  """
  def chat(messages, opts \\ []) do
    # Check if test mode is enabled
    if Application.get_env(:open_dev_coach, :test_ai, false) do
      log_ai_prompt(messages, opts)
      {:ok, "AI prompt logged to log/ai_prompts.log (test mode enabled)"}
    else
      provider = get_configured_provider()
      api_key = Configuration.get_config("ai_api_key")
      model = Configuration.get_config("ai_model")

      provider_opts = Keyword.merge(opts, api_key: api_key, model: model)

      case provider do
        :gemini ->
          Gemini.chat(messages, provider_opts)

        :openai ->
          {:error, "OpenAI provider not yet implemented"}

        :anthropic ->
          {:error, "Anthropic provider not yet implemented"}

        :ollama ->
          {:error, "Ollama provider not yet implemented"}

        nil ->
          {:error, "No AI provider configured. Set it with `/config set ai_provider gemini`"}

        unknown ->
          {:error,
           "Unknown AI provider: #{unknown}. Valid providers: gemini, openai, anthropic, ollama"}
      end
    end
  end

  @doc """
  Gets the currently configured AI provider.

  ## Returns
    - Provider atom (e.g., :gemini) or nil if not configured
  """
  def get_configured_provider do
    case Configuration.get_config("ai_provider") do
      "gemini" -> :gemini
      "openai" -> :openai
      "anthropic" -> :anthropic
      "ollama" -> :ollama
      nil -> nil
      unknown -> unknown
    end
  end

  @doc """
  Tests the current AI configuration by sending a simple message.

  ## Returns
    - `{:ok, "Test successful: <response>"}` on success
    - `{:error, error_message}` on failure
  """
  def test_configuration do
    messages = [%{role: "user", content: "Hello! Please respond with a brief greeting."}]

    case chat(messages) do
      {:ok, response} ->
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

  defp convert_opts_to_serializable(opts) do
    convert_value_to_serializable(opts)
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
