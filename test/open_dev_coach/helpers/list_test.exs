defmodule OpenDevCoach.Helpers.ListTest do
  use ExUnit.Case, async: true

  alias OpenDevCoach.Helpers.List, as: ListHelper

  describe "update_item_by_match/3" do
    test "updates only the first matching item" do
      list = [1, 2, 2, 3]

      assert {:ok, updated_item, new_list} =
               ListHelper.update_item_by_match(list, &(&1 == 2), &(&1 * 10))

      assert updated_item == 20
      assert new_list == [1, 20, 2, 3]
    end

    test "updates a more complex item" do
      list = [
        %{id: 1, name: "Item 1", value: 10},
        %{id: 2, name: "Item 2", value: 20},
        %{id: 3, name: "Item 3", value: 30}
      ]

      assert {:ok, updated_item, new_list} =
               ListHelper.update_item_by_match(
                 list,
                 &(&1.id == 2),
                 &Map.put(&1, :value, &1.value * 10)
               )

      assert updated_item.value == 200

      assert new_list == [
               %{id: 1, name: "Item 1", value: 10},
               %{id: 2, name: "Item 2", value: 200},
               %{id: 3, name: "Item 3", value: 30}
             ]
    end

    test "returns error when no items match" do
      list = [1, 3, 5]

      assert {:error, _reason} =
               ListHelper.update_item_by_match(list, &(&1 == 2), &(&1 * 10))
    end

    test "returns error for empty list" do
      assert {:error, _reason} =
               ListHelper.update_item_by_match([], &(&1 == 2), &(&1 * 10))
    end
  end
end
