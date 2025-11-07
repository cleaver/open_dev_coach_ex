defmodule OpenDevCoach.Servers.Session.Server do
  @moduledoc """
  GenServer implementation for the Session functionality.

  This module contains only the GenServer callbacks and delegates all business logic
  to the Impl module. It's pure server code with no application logic.
  """

  use GenServer

  import OpenDevCoach.Helpers.Future

  alias OpenDevCoach.Servers.Session.Impl

  @impl true
  def init(opts) do
    state = Impl.init(opts)
    {:ok, state}
  end

  # Task Management Callbacks

  @impl true
  def handle_call({:add_task, description}, _from, state) do
    {{:ok, tasks}, new_state} = Impl.add_task(state, description)
    {:reply, {:ok, tasks}, new_state}
  end

  def handle_call({:list_tasks}, _from, state) do
    {{:ok, tasks}, new_state} = Impl.list_tasks(state)
    {:reply, {:ok, tasks}, new_state}
  end

  def handle_call({:start_task, task_order}, _from, state) do
    case Impl.start_task(state, task_order) do
      {{:error, reason}, new_state} ->
        {:reply, {:error, reason}, new_state}

      {{:ok, tasks}, new_state} ->
        {:reply, {:ok, tasks}, new_state}
    end
  end

  def handle_call({:complete_task, task_order}, _from, state) do
    new_state = Impl.complete_task(state, task_order)
    {:reply, {:ok, "Task completed successfully"}, new_state}
  end

  def handle_call({:remove_task, task_order}, _from, state) do
    new_state = Impl.remove_task(state, task_order)
    {:reply, {:ok, "Task removed successfully"}, new_state}
  end

  def handle_call({:backup_tasks}, _from, state) do
    {result, new_state} = Impl.backup_tasks(state)
    {:reply, result, new_state}
  end

  # Configuration Management Callbacks

  def handle_call({:get_config, key}, _from, state) do
    {result, new_state} = Impl.get_config(state, key)

    reply =
      case result do
        {:ok, {key, value}} -> {:ok, {key, value}}
        {:error, key} -> {:error, key}
      end

    {:reply, reply, new_state}
  end

  def handle_call({:set_config, key, value}, _from, state) do
    {result, new_state} = Impl.set_config(state, key, value)
    {:reply, result, new_state}
  end

  def handle_call({:list_configs}, _from, state) do
    {{:ok, configs}, new_state} = Impl.list_configs(state)
    {:reply, {:ok, configs}, new_state}
  end

  def handle_call({:reset_config}, _from, state) do
    {result, new_state} = Impl.reset_config(state)
    {:reply, result, new_state}
  end

  def handle_call(:get_timezone, _from, state) do
    timezone = Impl.get_timezone(state)
    {:reply, timezone, state}
  end

  # AI Chat Callbacks

  def handle_call({:chat_with_ai, user_message}, _from, state) do
    {result, new_state} = Impl.chat_with_ai(state, user_message)
    {:reply, result, new_state}
  end

  def handle_call({:test_ai_config}, _from, state) do
    {result, new_state} = Impl.test_ai_config(state)
    {:reply, result, new_state}
  end

  def handle_call(_request, _from, state) do
    {:reply, Impl.get_timezone(state), state}
  end

  # Check-in handling

  @impl true
  def handle_cast({:handle_checkin, checkin}, state) do
    {_result, new_state} = Impl.handle_checkin(state, checkin)
    {:noreply, new_state}
  end

  # Configuration Management

  def handle_cast({:update_timezone, timezone}, state) do
    {:noreply, Impl.update_timezone(state, timezone)}
  end

  @impl true
  def handle_info(:ai_response, _message) do
    future(:handle_ai_response, "Handle async or streaming response.")
  end

  def handle_info({:error_message, message}, state) do
    Impl.output(:error, message)
    {:noreply, state}
  end
end
