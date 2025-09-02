defmodule OpenDevCoach.Helpers.Date do
  @moduledoc """
  Helper module for date and time operations.

  This module handles:
  - Time parsing (HH:MM format and intervals)
  - Timezone operations
  - DateTime calculations
  - Local time utilities
  """

  @doc """
  Gets the current local datetime in the configured timezone.
  """
  def local_datetime_now do
    Timex.now(local_timezone())
  end

  @doc """
  Gets the configured local timezone.
  """
  def local_timezone do
    Application.get_env(:open_dev_coach, :timezone, "America/New_York")
  end

  @doc """
  Calculates the next occurrence of a given hour and minute.

  If the time has already passed today, it returns tomorrow's occurrence.
  Otherwise, it returns today's occurrence.

  ## Parameters
    - hour: Hour in 24-hour format (0-23)
    - minute: Minute (0-59)

  ## Returns
    - {:ok, datetime} on success
    - {:error, reason} on failure
  """
  def next_time_hour_minute(hour, minute)
      when hour >= 0 and hour <= 23 and minute >= 0 and minute <= 59 do
    today = Timex.today()
    given_time = Timex.Time.new!(hour, minute, 0)
    given_time_today = Timex.DateTime.new!(today, given_time, local_timezone())

    if Timex.compare(given_time_today, local_datetime_now(), :minutes) <= 0 do
      {:ok, Timex.shift(given_time_today, days: 1)}
    else
      {:ok, given_time_today}
    end
  end

  def next_time_hour_minute(_hour, _minute),
    do: {:error, "Invalid time: hour must be 0-23, minute must be 0-59"}

  @doc """
  Parses time in HH:MM format and returns the next occurrence.

  ## Parameters
    - time_str: Time string in "HH:MM" format (e.g., "09:30")

  ## Returns
    - {:ok, datetime} on success
    - {:error, reason} on failure
  """
  def parse_time_format(time_str) do
    [hour_str, minute_str] = String.split(time_str, ":")
    hour = String.to_integer(hour_str)
    minute = String.to_integer(minute_str)

    next_time_hour_minute(hour, minute)
  end

  @doc """
  Parses interval format and returns the next occurrence.

  ## Parameters
    - interval_str: Interval string (e.g., "2h 30m", "30m", "1h")

  ## Returns
    - {:ok, datetime} on success
    - {:error, reason} on failure
  """
  def parse_interval_format(interval_str) do
    # Parse patterns like "2h 30m", "30m", "1h"
    hour_match = Regex.run(~r/(\d+)h/, interval_str)
    minute_match = Regex.run(~r/(\d+)m/, interval_str)

    hours = if hour_match, do: String.to_integer(Enum.at(hour_match, 1)), else: 0
    minutes = if minute_match, do: String.to_integer(Enum.at(minute_match, 1)), else: 0

    if hours == 0 and minutes == 0 do
      {:error, "Invalid interval: must specify at least one hour or minute"}
    else
      next_time =
        local_datetime_now()
        |> Timex.shift(hours: hours, minutes: minutes)

      {:ok, next_time}
    end
  end

  @doc """
  Parses either time format (HH:MM) or interval format and returns the next occurrence.

  ## Parameters
    - input: Time string in "HH:MM" format or interval like "2h 30m"

  ## Returns
    - {:ok, datetime} on success
    - {:error, reason} on failure
  """
  def parse_time_or_interval(input) when is_binary(input) do
    cond do
      # Handle HH:MM format (e.g., "09:30")
      Regex.match?(~r/^\d{1,2}:\d{2}$/, input) ->
        parse_time_format(input)

      # Handle interval format (e.g., "2h 30m", "30m")
      Regex.match?(~r/^\d+[hm]\s*\d*[hm]?$/, input) ->
        parse_interval_format(input)

      true ->
        {:error, "Invalid format. Use HH:MM (e.g., '09:30') or interval (e.g., '2h 30m')"}
    end
  end
end
