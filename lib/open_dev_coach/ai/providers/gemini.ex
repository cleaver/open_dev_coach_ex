defmodule OpenDevCoach.AI.Providers.Gemini do
  @moduledoc """
  Gemini AI provider implementation for OpenDevCoach.

  This module handles communication with Google's Gemini AI service
  through their REST API.
  """

  @behaviour OpenDevCoach.AI.Provider
  require Logger

  @gemini_base_url "https://generativelanguage.googleapis.com/v1beta/models"
  @default_model "gemini-flash-2.5"

  @doc """
  Sends a chat message to Gemini AI and returns the response.

  ## Parameters
    - messages: List of message maps with :role and :content keys
    - opts: Keyword list of options including :api_key and :model
    - http_client: HTTP client module (defaults to Req, injectable for testing)

  ## Returns
    - `{:ok, response_text}` on success
    - `{:error, error_message}` on failure
  """
  def chat(messages, opts, http_client \\ Req) do
    api_key = Keyword.get(opts, :api_key)
    model = Keyword.get(opts, :model, @default_model)

    case validate_request(api_key, messages) do
      :ok ->
        do_chat_request(messages, model, api_key, http_client)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp validate_request(api_key, messages) do
    cond do
      is_nil(api_key) or api_key == "" ->
        {:error, "API key is required. Set it with `/config set ai_api_key YOUR_KEY`"}

      is_nil(messages) or messages == [] ->
        {:error, "At least one message is required"}

      not Enum.all?(messages, &valid_message?/1) ->
        {:error, "Invalid message format. Messages must have :role and :content"}

      true ->
        :ok
    end
  end

  defp valid_message?(%{role: role, content: content})
       when is_binary(role) and is_binary(content) do
    true
  end

  defp valid_message?(_), do: false

  defp do_chat_request(messages, model, api_key, http_client) do
    url = "#{@gemini_base_url}/#{model}:generateContent?key=#{api_key}"
    request_body = build_request_body(messages)

    case http_client.post(url, json: request_body) do
      {:ok, %{status: 200, body: body}} ->
        parse_success_response(body)

      {:ok, %{status: status, body: body}} ->
        parse_error_response(status, body)

      {:error, %{__struct__: :req_request_error, reason: reason}} ->
        {:error, "Request failed: #{inspect(reason)}"}

      {:error, %{__struct__: :req_transport_error, reason: reason}} ->
        {:error, "Transport error: #{inspect(reason)}"}

      {:error, reason} ->
        {:error, "Unexpected error: #{inspect(reason)}"}
    end
  end

  defp build_request_body(messages) do
    %{
      contents:
        Enum.map(messages, fn %{role: _role, content: content} ->
          %{
            parts: [
              %{
                text: content
              }
            ]
          }
        end),
      generationConfig: %{
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 1024
      }
    }
  end

  defp parse_success_response(body) do
    # Body is already decoded when using json: option
    case body do
      %{"candidates" => [%{"content" => %{"parts" => [%{"text" => text} | _]}} | _]}
      when is_binary(text) ->
        {:ok, String.trim(text)}

      %{"candidates" => [%{"content" => %{"parts" => []}} | _]} ->
        {:error, "AI response is empty"}

      %{"candidates" => []} ->
        {:error, "AI returned no response"}

      response ->
        Logger.warning("Unexpected Gemini response format: #{inspect(response)}")
        {:error, "Unexpected response format from AI service"}
    end
  end

  defp parse_error_response(status, body) do
    # Body is already decoded when using json: option
    case body do
      %{"error" => %{"message" => message}} ->
        {:error, "AI service error (#{status}): #{message}"}

      _ ->
        {:error, "AI service error (#{status}): Unexpected response format"}
    end
  end
end
