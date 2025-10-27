defmodule OpenDevCoach.Servers.Scheduler do
  @moduledoc """
  Public API for the Scheduler functionality.

  This module provides the public interface for the Scheduler GenServer.
  It delegates all calls to the appropriate GenServer functions.
  """

  alias OpenDevCoach.Servers.Scheduler.Server

  @doc """
  Returns a child specification for the Scheduler GenServer.
  """
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  @doc """
  Starts the Scheduler GenServer.
  """
  def start_link(opts) do
    GenServer.start_link(Server, opts, name: __MODULE__)
  end

  @doc """
  Adds a new check-in to the scheduler.

  Parameters:
    - time_or_interval: Either "HH:MM" format or interval like "2h 30m"
    - description: Optional description for the check-in

  Returns:
    - {:ok, checkin_id} on success
    - {:error, reason} on failure
  """
  def add_checkin(time_or_interval, description \\ nil) do
    GenServer.call(__MODULE__, {:add_checkin, time_or_interval, description})
  end

  @doc """
  Lists all scheduled check-ins.
  """
  def list_checkins do
    GenServer.call(__MODULE__, :list_checkins)
  end

  @doc """
  Removes a scheduled check-in by ID.
  """
  def remove_checkin(checkin_id) do
    GenServer.call(__MODULE__, {:remove_checkin, checkin_id})
  end
end
