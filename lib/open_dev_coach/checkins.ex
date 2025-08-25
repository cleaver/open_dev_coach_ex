defmodule OpenDevCoach.Checkins do
  @moduledoc """
  Context module for managing check-ins in the database.

  This module provides functions for creating, reading, updating, and deleting
  check-ins, as well as querying active check-ins for the scheduler.
  """

  import Ecto.Query
  alias OpenDevCoach.Repo
  alias OpenDevCoach.Checkins.Checkin

  @doc """
  Creates a new check-in.
  """
  def create_checkin(attrs \\ %{}) do
    %Checkin{}
    |> Checkin.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a check-in by ID.
  """
  def get_checkin(id) do
    Repo.get(Checkin, id)
  end

  @doc """
  Lists all check-ins.
  """
  def list_checkins do
    Repo.all(Checkin)
  end

  @doc """
  Lists only active (non-completed) check-ins.
  """
  def list_active_checkins do
    Checkin
    |> where([c], c.status != "COMPLETED")
    |> order_by([c], c.scheduled_at)
    |> Repo.all()
  end

  @doc """
  Updates a check-in with the given attributes.
  """
  def update_checkin(%Checkin{} = checkin, attrs) do
    checkin
    |> Checkin.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a check-in.
  """
  def delete_checkin(%Checkin{} = checkin) do
    Repo.delete(checkin)
  end

  @doc """
  Changes the status of a check-in.
  """
  def change_checkin_status(checkin, status) do
    update_checkin(checkin, %{status: status})
  end

  @doc """
  Marks a check-in as completed.
  """
  def complete_checkin(checkin) do
    update_checkin(checkin, %{
      status: "COMPLETED",
      completed_at: DateTime.utc_now()
    })
  end
end
