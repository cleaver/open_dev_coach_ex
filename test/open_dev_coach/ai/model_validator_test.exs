defmodule OpenDevCoach.Ai.ModelValidatorTest do
  use ExUnit.Case, async: true

  alias OpenDevCoach.Ai.ModelValidator

  describe "validate_provider/1" do
    test "returns true for valid provider string" do
      # Test with a known valid provider
      assert ModelValidator.validate_provider("anthropic") == true
    end

    test "returns true for valid provider atom" do
      # Test with a known valid provider
      assert ModelValidator.validate_provider(:anthropic) == true
    end

    test "returns false for invalid provider string" do
      assert ModelValidator.validate_provider("invalid_provider") == false
    end

    test "returns false for invalid provider atom" do
      assert ModelValidator.validate_provider(:invalid_provider) == false
    end

    test "handles empty string" do
      assert ModelValidator.validate_provider("") == false
    end

    test "handles nil-like atoms" do
      assert ModelValidator.validate_provider(nil) == false
    end

    test "validates real providers and models" do
      # Test that we can validate actual providers that should exist
      valid_providers = ["anthropic", "openai", "google"]

      for provider <- valid_providers do
        assert ModelValidator.validate_provider(provider) == true,
               "Provider #{provider} should be valid"
      end
    end
  end

  describe "validate_model/1" do
    test "returns true for valid model string" do
      # Test with a known valid model
      assert ModelValidator.validate_model("anthropic:claude-3-haiku-20240307") == true
    end

    test "returns false for invalid model string" do
      assert ModelValidator.validate_model("invalid:model") == false
    end

    test "returns false for malformed model string" do
      assert ModelValidator.validate_model("invalid-format") == false
    end

    test "returns false for empty string" do
      assert ModelValidator.validate_model("") == false
    end

    test "returns false for nil" do
      assert ModelValidator.validate_model(nil) == false
    end

    test "returns false for invalid tuple format" do
      assert ModelValidator.validate_model({:invalid, "model", []}) == false
    end

    test "returns true for valid tuple format" do
      assert ModelValidator.validate_model({:anthropic, "claude-3-haiku-20240307", []}) == true
    end

    test "returns true for valid model struct" do
      model = %ReqLLM.Model{
        provider: :anthropic,
        model: "claude-3-haiku-20240307",
        max_retries: 3
      }

      assert ModelValidator.validate_model(model) == true
    end

    test "returns false for invalid model struct" do
      model = %ReqLLM.Model{provider: :invalid, model: "model", max_retries: 3}
      assert ModelValidator.validate_model(model) == false
    end

    test "validates real models" do
      # Test that we can validate actual models that should exist
      valid_models = [
        "anthropic:claude-3-haiku-20240307",
        "anthropic:claude-3-sonnet-20240229"
      ]

      for model <- valid_models do
        assert ModelValidator.validate_model(model) == true,
               "Model #{model} should be valid"
      end
    end
  end
end
