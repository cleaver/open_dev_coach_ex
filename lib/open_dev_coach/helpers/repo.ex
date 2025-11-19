defmodule OpenDevCoach.Helpers.Repo do
  @moduledoc """
  Provides utility functions for working with Ecto Repo operations.

  This module includes helpers for handling database-specific concerns,
  such as retry logic for SQLite "Database busy" errors.
  """

  @doc """
  Retries a database operation with exponential backoff when encountering "Database busy" errors.

  This is particularly useful for SQLite databases that may encounter concurrent access issues.

  ## Parameters

    * `fun` - A zero-arity function that performs the database operation
    * `max_retries` - Maximum number of retry attempts (default: 5)
    * `base_delay_ms` - Initial delay in milliseconds before retrying (default: 10)

  ## Examples

      RepoHelper.retry_with_backoff(fn ->
        Repo.insert(changeset)
      end)

      RepoHelper.retry_with_backoff(fn ->
        Repo.update(changeset)
      end, max_retries: 10, base_delay_ms: 20)

  """
  def retry_with_backoff(fun, max_retries \\ 5, base_delay_ms \\ 10) do
    try do
      fun.()
    rescue
      e ->
        error_message = Exception.message(e)
        is_database_busy = String.contains?(error_message, "Database busy")

        if is_database_busy and max_retries > 0 do
          :timer.sleep(base_delay_ms)
          retry_with_backoff(fun, max_retries - 1, base_delay_ms * 2)
        else
          reraise e, __STACKTRACE__
        end
    catch
      :exit, reason ->
        error_message =
          case reason do
            {:exception, %{message: message}} -> message
            %{message: message} -> message
            _ -> inspect(reason)
          end

        is_database_busy = String.contains?(error_message, "Database busy")

        if is_database_busy and max_retries > 0 do
          :timer.sleep(base_delay_ms)
          retry_with_backoff(fun, max_retries - 1, base_delay_ms * 2)
        else
          exit(reason)
        end
    end
  end
end
