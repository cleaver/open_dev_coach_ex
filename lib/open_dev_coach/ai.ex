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
end
