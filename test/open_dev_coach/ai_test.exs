defmodule OpenDevCoach.AITest do
  use ExUnit.Case, async: false
  alias OpenDevCoach.AI
  alias OpenDevCoach.AI.Providers.Gemini
  alias OpenDevCoach.Configuration

  setup do
    # Clean up any existing configuration before each test
    Configuration.reset_config()
    :ok
  end

  describe "AI Provider Behaviour" do
    test "gemini_provider_implements_behaviour" do
      # Verify Gemini implements the Provider behaviour
      assert {:chat, 2} in Gemini.__info__(:functions)
    end
  end

  describe "AI Factory" do
    test "get_configured_provider_returns_nil_when_not_configured" do
      # This test assumes no provider is configured in the test environment
      # The function should return nil when no provider is configured
      provider = AI.get_configured_provider()
      # Should be nil when no provider is configured
      assert provider == nil
    end

    test "chat_returns_error_when_no_provider_configured" do
      # Test that chat returns an error when no provider is configured
      result = AI.chat([%{role: "user", content: "Hello"}])
      # Should return some kind of error
      assert {:error, _} = result
    end
  end

  describe "Gemini Provider" do
    test "chat_validates_api_key_requirement" do
      result = Gemini.chat([%{role: "user", content: "Hello"}], [])

      assert {:error, "API key is required. Set it with `/config set ai_api_key YOUR_KEY`"} =
               result
    end

    test "chat_validates_message_format" do
      result = Gemini.chat([], api_key: "test")
      assert {:error, "At least one message is required"} = result
    end

    test "chat_validates_message_structure" do
      result = Gemini.chat([%{invalid: "message"}], api_key: "test")
      assert {:error, "Invalid message format. Messages must have :role and :content"} = result
    end
  end
end
