defmodule OpenDevCoach.Helpers.Persistence do
  @moduledoc """
  Provides functions for persisting changes asynchronously.
  """

  alias OpenDevCoach.Helpers.List, as: ListHelper

  @doc """
  Handles updating an item in a GenServer's state and persisting the change asynchronously.

  This function encapsulates the pattern of:
  1. Preparing an Ecto changeset using a provided function.
  2. Applying the changeset to get an updated item for in-memory state.
  3. Updating the collection in the GenServer state.
  4. Asynchronously persisting the changeset to the database.

  ## Options

    * `collection_key`: (Required) The key in the state map that holds the list of items.
    * `prepare_changeset`: (Required) A function that takes an item and attributes and returns a changeset.
    * `apply_changeset`: (Required) A function that takes a valid changeset and returns the updated item.
    * `persist_changeset`: (Required) A function that takes a valid changeset and persists it.
    * `id_key`: (Optional) The key in the item struct that holds the unique identifier. Defaults to `:id`.

  ## Example

      defp update_checkin(state, checkin, attrs) do
        update_in_memory_and_persist_async(
          state,
          checkin,
          attrs,
          collection_key: :checkins,
          prepare_changeset: &Checkins.prepare_update_changeset/2,
          apply_changeset: &Checkins.apply_update_changeset/1,
          persist_changeset: &Checkins.persist_update_changeset/1
        )
      end
  """
  def update_in_memory_and_persist_async(state, item, attrs, opts) do
    collection_key = Keyword.fetch!(opts, :collection_key)
    prepare_changeset_fn = Keyword.fetch!(opts, :prepare_changeset)
    apply_changeset_fn = Keyword.fetch!(opts, :apply_changeset)
    persist_changeset_fn = Keyword.fetch!(opts, :persist_changeset)
    id_key = Keyword.get(opts, :id_key, :id)

    case prepare_changeset_fn.(item, attrs) do
      %Ecto.Changeset{valid?: true} = changeset ->
        updated_item = apply_changeset_fn.(changeset)

        collection = Map.get(state, collection_key)
        item_id = Map.get(item, id_key)

        updated_collection =
          ListHelper.update_item_by_match(collection, &(&1 |> Map.get(id_key) == item_id), fn _ ->
            updated_item
          end)

        if async_persistence?(),
          do: Task.start(fn -> persist_changeset_fn.(changeset) end),
          else: persist_changeset_fn.(changeset)

        new_state = Map.put(state, collection_key, updated_collection)
        {updated_item, new_state}

      _changeset ->
        {:error, state}
    end
  end

  @doc """
  Handles adding an item to a GenServer's state and persisting it asynchronously.

  This function encapsulates the pattern of:
  1. Creating a new struct from attributes.
  2. Adding the new item to a collection in the GenServer state.
  3. Asynchronously persisting the attributes to the database.
  4. Returning the new item and the updated state.

  ## Options

    * `collection_key`: (Required) The key in the state map that holds the list of items.
    * `struct_module`: (Required) The module of the struct to be created.
    * `persist_function`: (Required) A function that takes attributes and persists them.
    * `id_key`: (Optional) The key in the attributes that holds the unique identifier. Defaults to `:id`.

  ## Example

      {checkin, new_state_with_checkin} =
        add_in_memory_and_persist_async(
          state,
          attrs,
          collection_key: :checkins,
          struct_module: Checkin,
          persist_function: &Checkins.create_checkin/1
        )
  """
  def add_in_memory_and_persist_async(state, attrs, opts) do
    collection_key = Keyword.fetch!(opts, :collection_key)
    struct_module = Keyword.fetch!(opts, :struct_module)
    persist_function = Keyword.fetch!(opts, :persist_function)
    id_key = Keyword.get(opts, :id_key, :id)

    attrs_with_id =
      if Map.has_key?(attrs, id_key) or
           Map.has_key?(attrs, to_string(id_key)) do
        attrs
      else
        Map.put(attrs, id_key, Ecto.UUID.generate())
      end

    item = struct(struct_module, attrs_with_id)

    collection = Map.get(state, collection_key, [])
    new_collection = [item | collection]
    new_state = Map.put(state, collection_key, new_collection)

    if async_persistence?(),
      do: Task.start(fn -> persist_function.(attrs_with_id) end),
      else: persist_function.(attrs_with_id)

    {item, new_state}
  end

  @doc """
  Checks if async persistence is enabled.

  Returns true if async persistence is enabled, false otherwise.
  Defaults to true if not configured.
  """
  def async_persistence? do
    Application.get_env(:open_dev_coach, :async_persistence, true)
  end
end
