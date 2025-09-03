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

  ## Examples

      iex> {:ok, datetime} = OpenDevCoach.Helpers.Date.next_time_hour_minute(14, 30)
      iex> datetime.hour
      14
      iex> datetime.minute
      30
      iex> datetime.time_zone
      "America/New_York"

      iex> OpenDevCoach.Helpers.Date.next_time_hour_minute(24, 30)
      {:error, "Invalid time: hour must be 0-23, minute must be 0-59"}

      iex> OpenDevCoach.Helpers.Date.next_time_hour_minute(12, 60)
      {:error, "Invalid time: hour must be 0-23, minute must be 0-59"}
  """
  def next_time_hour_minute(hour, minute, local_time_now \\ local_datetime_now())

  def next_time_hour_minute(hour, minute, local_time_now)
      when hour >= 0 and hour <= 23 and minute >= 0 and minute <= 59 do
    todays_date = Timex.to_date(local_time_now)
    given_time = Timex.Time.new!(hour, minute, 0)
    given_time_today = Timex.DateTime.new!(todays_date, given_time, local_timezone())

    if Timex.compare(given_time_today, local_time_now, :minutes) <= 0 do
      {:ok, Timex.shift(given_time_today, days: 1)}
    else
      {:ok, given_time_today}
    end
  end

  def next_time_hour_minute(_hour, _minute, _local_time_now),
    do: {:error, "Invalid time: hour must be 0-23, minute must be 0-59"}

  @doc """
  Parses time in HH:MM format and returns the next occurrence.

  ## Parameters
    - time_str: Time string in "HH:MM" format (e.g., "09:30")

  ## Returns
    - {:ok, datetime} on success
    - {:error, reason} on failure

  ## Examples

      iex> {:ok, datetime} = OpenDevCoach.Helpers.Date.parse_time_format("14:30")
      iex> datetime.hour
      14
      iex> datetime.minute
      30

      iex> {:ok, datetime} = OpenDevCoach.Helpers.Date.parse_time_format("09:15")
      iex> datetime.hour
      9
      iex> datetime.minute
      15

      iex> OpenDevCoach.Helpers.Date.parse_time_format("25:30")
      {:error, "Invalid time: hour must be 0-23, minute must be 0-59"}
  """
  def parse_time_format(time_str, local_time_now \\ local_datetime_now()) do
    [hour_str, minute_str] = String.split(time_str, ":")
    hour = String.to_integer(hour_str)
    minute = String.to_integer(minute_str)

    next_time_hour_minute(hour, minute, local_time_now)
  end

  @doc """
  Parses interval format and returns the next occurrence.

  ## Parameters
    - interval_str: Interval string (e.g., "2h 30m", "30m", "1h")

  ## Returns
    - {:ok, datetime} on success
    - {:error, reason} on failure

  ## Examples

      iex> {:ok, datetime} = OpenDevCoach.Helpers.Date.parse_interval_format("2h")
      iex> %DateTime{} = datetime

      iex> {:ok, datetime} = OpenDevCoach.Helpers.Date.parse_interval_format("30m")
      iex> %DateTime{} = datetime

      iex> {:ok, datetime} = OpenDevCoach.Helpers.Date.parse_interval_format("2h 30m")
      iex> %DateTime{} = datetime

      iex> OpenDevCoach.Helpers.Date.parse_interval_format("0h 0m")
      {:error, "Invalid interval: must specify at least one hour or minute"}
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

  ## Examples

      iex> {:ok, datetime} = OpenDevCoach.Helpers.Date.parse_time_or_interval("14:30")
      iex> datetime.hour
      14
      iex> datetime.minute
      30

      iex> {:ok, datetime} = OpenDevCoach.Helpers.Date.parse_time_or_interval("2h 30m")
      iex> %DateTime{} = datetime

      iex> OpenDevCoach.Helpers.Date.parse_time_or_interval("invalid")
      {:error, "Invalid format. Use HH:MM (e.g., '09:30') or interval (e.g., '2h 30m')"}
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
