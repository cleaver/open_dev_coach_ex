defmodule OpenDevCoach.SessionAITest do
  use ExUnit.Case, async: false
  alias OpenDevCoach.Session
  alias OpenDevCoach.Configuration

  setup do
    # Clean up any existing configuration
    Configuration.reset_config()
    :ok
  end

  describe "AI Integration" do
    test "chat_with_ai_returns_error_when_no_provider_configured" do
      result = Session.chat_with_ai("Hello, how are you?")

      assert {:error,
              "AI service error: No AI provider configured. Set it with `/config set ai_provider gemini`"} =
               result
    end

    test "chat_with_ai_works_with_gemini_provider" do
      # Set up Gemini configuration
      Configuration.set_config("ai_provider", "gemini")
      Configuration.set_config("ai_api_key", "test_key")
      Configuration.set_config("ai_model", "gemini-pro")

      # Test that it now recognizes the provider
      result = Session.chat_with_ai("Hello")
      # Should fail due to invalid API key, but not due to missing provider
      assert {:error, _} = result
      refute String.contains?(result |> elem(1), "No AI provider configured")
    end

    test "test_ai_config_works" do
      # Test without configuration
      result = Session.test_ai_config()
      assert {:error, _} = result

      # Test with configuration
      Configuration.set_config("ai_provider", "gemini")
      Configuration.set_config("ai_api_key", "test_key")

      result = Session.test_ai_config()
      assert {:error, _} = result
      refute String.contains?(result |> elem(1), "No AI provider configured")
    end
  end
end
