defmodule OpenDevCoach.AI do
  @moduledoc """
  AI factory module for OpenDevCoach.

  This module acts as the main entry point for AI interactions,
  using the ReqLLM library to communicate with various providers.
  """

  alias OpenDevCoach.Configuration
  import ReqLLM.Context

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
    if Application.get_env(:open_dev_coach, :test_ai, false) do
      log_ai_prompt(messages, opts)
      {:ok, %{text: "AI prompt logged to log/ai_prompts.log (test mode enabled)", tool_calls: []}}
    else
      with {:ok, provider_name} <- get_configured_provider_name(),
           api_key <- Configuration.get_config("ai_api_key"),
           model_name <- Configuration.get_config("ai_model") do
        model_spec = "#{provider_name}:#{model_name}"
        context = build_context(messages)

        # Set the API key in memory for ReqLLM to use
        provider_atom = String.to_atom(provider_name)
        config_key = ReqLLM.Keys.config_key(provider_atom)
        ReqLLM.put_key(config_key, api_key)

        case ReqLLM.generate_text(model_spec, context, opts) do
          {:ok, response} ->
            text = ReqLLM.Response.text(response)
            tool_calls = response.message.content |> Enum.filter(&(&1.type == :tool_call))
            {:ok, %{text: text, tool_calls: tool_calls}}

          {:error, reason} ->
            {:error, "ReqLLM error: #{inspect(reason)}"}
        end
      else
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp build_context(messages) do
    messages
    |> Enum.map(fn
      %{role: "user", content: content} -> user(content)
      %{role: "assistant", content: content} -> assistant(content)
      %{role: "system", content: content} -> system(content)
    end)
    |> ReqLLM.Context.new()
  end

  @doc """
  Gets the currently configured AI provider name for ReqLLM.

  ## Returns
    - `{:ok, provider_name}` (e.g., "google") or `{:error, reason}`
  """
  @provider_map %{
    "gemini" => {:ok, "google"},
    "openai" => {:ok, "openai"},
    "anthropic" => {:ok, "anthropic"},
    "groq" => {:ok, "groq"},
    "xai" => {:ok, "xai"},
    "openrouter" => {:ok, "openrouter"},
    "ollama" => {:error, "Ollama provider not yet supported by ReqLLM"}
  }

  def get_configured_provider_name do
    provider = Configuration.get_config("ai_provider")

    if is_nil(provider) do
      {:error, "No AI provider configured. Set it with `/config set ai_provider gemini`"}
    else
      Map.get(
        @provider_map,
        provider,
        {:error, "Unknown or unsupported AI provider: #{provider}"}
      )
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
      {:ok, %{text: response}} when is_binary(response) ->
        {:ok, "Test successful: #{response}"}

      {:ok, _} ->
        {:error, "Test failed: AI response was not in the expected format."}

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
