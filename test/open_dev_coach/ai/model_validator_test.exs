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

    test "validates main providers" do
      # Test that we can validate main providers that should exist
      main_providers = ["anthropic", "openai", "google"]
      found_valid_providers = Enum.filter(main_providers, &ModelValidator.validate_provider/1)

      assert length(found_valid_providers) >= 1,
             "Should find at least one valid main provider (#{inspect(main_providers)}), found: #{inspect(found_valid_providers)}"
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

    test "validates models from main providers" do
      # Test that we can validate models from main providers
      main_providers = [:anthropic, :openai, :google]

      for provider <- main_providers do
        # Skip if provider is not available
        if ModelValidator.validate_provider(provider) do
          models = ModelValidator.list_models_for_provider(provider)

          # Should have at least one valid model
          assert length(models) > 0, "Provider #{provider} should have at least one model"

          # Test that we can validate at least one model from this provider
          valid_models = Enum.filter(models, &ModelValidator.validate_model/1)

          assert length(valid_models) > 0,
                 "Provider #{provider} should have at least one valid model"
        end
      end
    end
  end

  describe "list_providers/0" do
    test "returns a list of available providers" do
      providers = ModelValidator.list_providers()

      assert is_list(providers)
      assert length(providers) > 0

      # Should include at least the main providers (these are stable)
      main_providers = [:anthropic, :openai, :google]
      found_main_providers = Enum.filter(main_providers, &(&1 in providers))

      assert length(found_main_providers) >= 1,
             "Should find at least one main provider (#{inspect(main_providers)}), found: #{inspect(found_main_providers)}"

      # All returned providers should be valid
      for provider <- providers do
        assert ModelValidator.validate_provider(provider) == true,
               "Provider #{provider} should be valid"
      end

      # All providers should be atoms
      for provider <- providers do
        assert is_atom(provider), "Provider #{provider} should be an atom"
      end
    end
  end

  describe "list_models_for_provider/1" do
    test "returns models for main providers" do
      # Test with main providers that should be stable
      main_providers = [:anthropic, :openai, :google]

      for provider <- main_providers do
        # Skip if provider is not available
        if ModelValidator.validate_provider(provider) do
          models = ModelValidator.list_models_for_provider(provider)

          assert is_list(models)
          # Don't assert specific length as models may change

          # All models should be valid and start with provider name
          for model <- models do
            provider_string = Atom.to_string(provider)

            assert String.starts_with?(model, "#{provider_string}:"),
                   "Model #{model} should start with #{provider_string}:"

            assert ModelValidator.validate_model(model) == true,
                   "Model #{model} should be valid"
          end
        end
      end
    end

    test "returns models for valid provider string" do
      # Test with string input for main providers
      main_providers = ["anthropic", "openai", "google"]

      for provider_string <- main_providers do
        provider_atom = String.to_atom(provider_string)

        # Skip if provider is not available
        if ModelValidator.validate_provider(provider_atom) do
          models = ModelValidator.list_models_for_provider(provider_string)

          assert is_list(models)

          # All models should be valid and start with provider name
          for model <- models do
            assert String.starts_with?(model, "#{provider_string}:"),
                   "Model #{model} should start with #{provider_string}:"

            assert ModelValidator.validate_model(model) == true,
                   "Model #{model} should be valid"
          end
        end
      end
    end

    test "returns empty list for invalid provider" do
      models = ModelValidator.list_models_for_provider(:invalid_provider)
      assert models == []

      models = ModelValidator.list_models_for_provider("invalid_provider")
      assert models == []
    end
  end

  describe "list_all_models/1" do
    test "returns all available models" do
      all_models = ModelValidator.list_all_models()

      assert is_list(all_models)
      assert length(all_models) > 0

      # Should include models from multiple providers (check main ones)
      main_providers = ["anthropic", "openai", "google"]

      found_providers =
        main_providers
        |> Enum.filter(fn provider ->
          Enum.any?(all_models, &String.starts_with?(&1, "#{provider}:"))
        end)

      assert length(found_providers) >= 1,
             "Should find models from at least one main provider (#{inspect(main_providers)}), found: #{inspect(found_providers)}"

      # All models should be valid
      for model <- all_models do
        assert ModelValidator.validate_model(model) == true,
               "Model #{model} should be valid"
      end

      # All models should be strings in provider:model format
      for model <- all_models do
        assert is_binary(model), "Model #{model} should be a string"
        assert String.contains?(model, ":"), "Model #{model} should contain ':'"
      end
    end

    test "filters by provider" do
      # Test filtering by main providers
      main_providers = [:anthropic, :openai, :google]

      for provider <- main_providers do
        # Skip if provider is not available
        if ModelValidator.validate_provider(provider) do
          filtered_models = ModelValidator.list_all_models(provider: provider)

          assert is_list(filtered_models)

          # All models should be from the specified provider
          provider_string = Atom.to_string(provider)

          for model <- filtered_models do
            assert String.starts_with?(model, "#{provider_string}:"),
                   "Model #{model} should start with #{provider_string}:"
          end
        end
      end
    end

    test "filters by provider string" do
      # Test filtering by provider string
      main_providers = ["anthropic", "openai", "google"]

      for provider_string <- main_providers do
        provider_atom = String.to_atom(provider_string)

        # Skip if provider is not available
        if ModelValidator.validate_provider(provider_atom) do
          filtered_models = ModelValidator.list_all_models(provider: provider_string)

          assert is_list(filtered_models)

          # All models should be from the specified provider
          for model <- filtered_models do
            assert String.starts_with?(model, "#{provider_string}:"),
                   "Model #{model} should start with #{provider_string}:"
          end
        end
      end
    end

    test "returns empty list for invalid provider filter" do
      models = ModelValidator.list_all_models(provider: :invalid_provider)
      assert models == []

      models = ModelValidator.list_all_models(provider: "invalid_provider")
      assert models == []
    end

    test "returns model structs when format is :model_struct" do
      models = ModelValidator.list_all_models(format: :model_struct)

      assert is_list(models)
      assert length(models) > 0

      # All items should be ReqLLM.Model structs
      for model <- models do
        assert %ReqLLM.Model{} = model
        assert is_atom(model.provider)
        assert is_binary(model.model)
      end
    end

    test "filters by with_tool_calls" do
      # Test that with_tool_calls filters to only models that support tool calls
      all_models = ModelValidator.list_all_models()
      models_with_tool_calls = ModelValidator.list_all_models(with_tool_calls: true)

      assert is_list(models_with_tool_calls)
      assert length(models_with_tool_calls) <= length(all_models)

      # All returned models should support tool calls
      for model_string <- models_with_tool_calls do
        case ReqLLM.Model.from(model_string) do
          {:ok, model} ->
            # This model should support tool calls
            assert Map.get(model.capabilities, :tool_call, false) == true,
                   "Model #{model_string} should support tool_call capability"

          {:error, _} ->
            # Skip validation for models that can't be parsed
            :ok
        end
      end
    end

    test "combines multiple filters" do
      # Test combining filters with main providers
      main_providers = [:anthropic, :openai, :google]

      for provider <- main_providers do
        # Skip if provider is not available
        if ModelValidator.validate_provider(provider) do
          filtered_models =
            ModelValidator.list_all_models(
              provider: provider,
              with_tool_calls: true,
              format: :model_struct
            )

          assert is_list(filtered_models)

          # All items should be ReqLLM.Model structs from the specified provider with tool calls
          for model <- filtered_models do
            assert %ReqLLM.Model{} = model
            assert model.provider == provider
            assert Map.get(model.capabilities, :tool_call, false) == true
          end
        end
      end
    end
  end
end
