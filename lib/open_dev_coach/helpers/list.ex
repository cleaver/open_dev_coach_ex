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

  @doc """
  Map and inumerable and apply a filter function to the results. The `map_fn` is applied first, and the the `filter_fn` is applied to the results.
  Parameters:
    - enum: The enumerable to map and filter
    - filter_fn: The function to filter the results
    - map_fn: The function to map the results
  Returns:
    - The mapped and filtered enumerable
  """
  @spec map_filter(Enumerable.t(), (any() -> any()), (any() -> boolean())) :: Enumerable.t()
  def map_filter(enum, map_fn, filter_fn) do
    for x <- enum, result = map_fn.(x), filter_fn.(result) == true, do: result
  end
end
