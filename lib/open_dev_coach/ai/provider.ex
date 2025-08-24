defmodule OpenDevCoach.AI.Provider do
  @moduledoc """
  Behaviour defining the contract for AI providers.

  All AI providers must implement the `chat/2` function to be compatible
  with the OpenDevCoach AI system.
  """

  @doc """
  Sends a chat message to the AI provider and returns the response.

  ## Parameters
    - messages: List of message maps with :role and :content keys
    - opts: Keyword list of additional options (e.g., model, temperature)

  ## Returns
    - `{:ok, response_text}` on success
    - `{:error, error_message}` on failure

  ## Example
      iex> messages = [%{role: "user", content: "Hello, how are you?"}]
      iex> opts = [model: "gemini-pro", temperature: 0.7]
      iex> Provider.chat(messages, opts)
      {:ok, "Hello! I'm doing well, thank you for asking."}
  """
  @callback chat(messages :: [map()], opts :: keyword()) ::
              {:ok, String.t()} | {:error, String.t()}
end
