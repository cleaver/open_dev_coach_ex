defmodule OpenDevCoach.Helpers.List do
  @moduledoc """
  Helper module for working with lists.
  """

  @doc """
  Update the first matching item in a list by matching function with an update function.
  Parameters:
    - list: The list to update
    - match_fn: The function to match the item to update
    - update_fn: The function to update the item
  Returns:
    - {:ok, updated_item, new_list} on success
    - {:error, reason} on failure
  """
  def update_item_by_match([], _match_fn, _update_fn) do
    {:error, "List is empty"}
  end

  def update_item_by_match(list, match_fn, update_fn) do
    case Enum.find_index(list, match_fn) do
      nil ->
        {:error, "No matching item found"}

      index ->
        item = Enum.at(list, index)
        updated_item = update_fn.(item)
        new_list = List.replace_at(list, index, updated_item)
        {:ok, updated_item, new_list}
    end
  end
end
