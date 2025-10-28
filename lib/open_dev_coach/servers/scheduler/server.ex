defmodule OpenDevCoach.Servers.Scheduler.Server do
  @moduledoc """
  GenServer implementation for the Scheduler functionality.

  This module contains only the GenServer callbacks and delegates all business logic
  to the Impl module. It's pure server code with no application logic.
  """

  use GenServer
  alias OpenDevCoach.Servers.Scheduler.Impl

  @impl true
  def init(opts) do
    state = Impl.init(opts)
    {:ok, state}
  end

  @impl true
  def handle_call({:add_checkin, time_or_interval, description}, _from, state) do
    {result, new_state} = Impl.add_checkin(state, time_or_interval, description)
    {:reply, result, new_state}
  end

  def handle_call(:list_checkins, _from, state) do
    {checkins, new_state} = Impl.list_checkins(state)
    {:reply, checkins, new_state}
  end

  def handle_call({:remove_checkin, checkin_id}, _from, state) do
    {result, new_state} = Impl.remove_checkin(state, checkin_id)
    {:reply, result, new_state}
  end

  @impl true
  def handle_info({:checkin, checkin_id}, state) do
    {_result, new_state} = Impl.handle_checkin_trigger(state, checkin_id)
    {:noreply, new_state}
  end
end
