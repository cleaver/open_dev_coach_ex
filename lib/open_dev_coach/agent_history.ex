defmodule OpenDevCoach.AgentHistory do
  @moduledoc """
  Context module for managing agent history in the OpenDevCoach application.

  This module provides functions to store and retrieve AI conversation history,
  task changes, and other meaningful interactions.
  """

  import Ecto.Query
  alias OpenDevCoach.AgentHistory.Entry
  alias OpenDevCoach.Repo

  @doc """
  Adds a new conversation entry to the agent history.

  ## Parameters
    - role: The role of the message sender ("user" or "assistant")
    - content: The content of the message

  ## Returns
    - `{:ok, entry}` on success
    - `{:error, changeset}` on failure
  """
  def add_conversation(role, content) when is_binary(role) and is_binary(content) do
    %Entry{}
    |> Entry.changeset(%{
      role: role,
      content: content,
      timestamp: DateTime.utc_now()
    })
    |> Repo.insert()
  end

  @doc """
  Retrieves recent conversation history for context.

  ## Parameters
    - limit: Maximum number of entries to return (default: 10)

  ## Returns
    - List of recent conversation entries
  """
  def get_recent_history(limit \\ 10) do
    Entry
    |> order_by([e], desc: e.timestamp)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Retrieves conversation history for a specific task.

  ## Parameters
    - task_id: The ID of the task to get history for

  ## Returns
    - List of conversation entries related to the task
  """
  def get_task_history(task_id) when is_integer(task_id) do
    # For now, return empty list since we don't have task metadata
    # This can be enhanced in future versions
    []
  end

  @doc """
  Retrieves conversation history for a specific time period.

  ## Parameters
    - since: DateTime to get history since

  ## Returns
    - List of conversation entries since the specified time
  """
  def get_history_since(since) when is_struct(since, DateTime) do
    Entry
    |> where([e], e.timestamp >= ^since)
    |> order_by([e], asc: e.timestamp)
    |> Repo.all()
  end

  @doc """
  Cleans up old conversation history.

  ## Parameters
    - days: Number of days to keep (default: 30)

  ## Returns
    - Number of entries deleted
  """
  def cleanup_old_history(days \\ 30) do
    cutoff_date = DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)

    from(e in Entry, where: e.timestamp < ^cutoff_date)
    |> Repo.delete_all()
  end
end
