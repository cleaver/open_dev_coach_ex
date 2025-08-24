defmodule OpenDevCoach.AI.IntegrationTest do
  use OpenDevCoach.DataCase, async: false
  alias OpenDevCoach.Session
  alias OpenDevCoach.Configuration
  alias OpenDevCoach.CLI.Commands

  setup do
    # Clean up any existing configuration
    Configuration.reset_config()
    :ok
  end

  describe "Full AI Integration" do
    test "complete_ai_workflow" do
      # 1. Test that no AI provider is configured initially
      assert {:error, _} = Session.chat_with_ai("Hello")

      # 2. Configure Gemini provider
      Configuration.set_config("ai_provider", "gemini")
      Configuration.set_config("ai_api_key", "test_key")
      Configuration.set_config("ai_model", "gemini-pro")

      # 3. Test that provider is now recognized
      provider = OpenDevCoach.AI.get_configured_provider()
      assert provider == :gemini

      # 4. Test that chat now fails due to invalid API key, not missing provider
      result = Session.chat_with_ai("Hello")
      assert {:error, _} = result
      refute String.contains?(elem(result, 1), "No AI provider configured")
      assert String.contains?(elem(result, 1), "API key not valid")

      # 5. Test CLI integration
      cli_result = Commands.handle_unknown("Hello, AI coach!")
      assert {:error, _} = cli_result
      assert String.contains?(elem(cli_result, 1), "AI service error")

      # 6. Test configuration test command
      test_result = Session.test_ai_config()
      assert {:error, _} = test_result
      refute String.contains?(elem(test_result, 1), "No AI provider configured")
    end

    test "ai_factory_routing" do
      # Test that AI factory properly routes to configured provider
      Configuration.set_config("ai_provider", "gemini")
      Configuration.set_config("ai_api_key", "test_key")

      result = OpenDevCoach.AI.chat([%{role: "user", content: "Hello"}])
      assert {:error, _} = result
      refute String.contains?(elem(result, 1), "No AI provider configured")

      # Test unknown provider
      Configuration.set_config("ai_provider", "unknown")
      result = OpenDevCoach.AI.chat([%{role: "user", content: "Hello"}])
      assert {:error, _} = result
      assert String.contains?(elem(result, 1), "Unknown AI provider: unknown")
    end
  end
end
