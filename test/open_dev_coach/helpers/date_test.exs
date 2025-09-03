defmodule OpenDevCoach.Helpers.DateTest do
  use ExUnit.Case, async: true
  alias OpenDevCoach.Helpers.Date, as: DateHelper
  doctest OpenDevCoach.Helpers.Date

  # Mock the timezone for consistent testing
  setup do
    # Set a fixed timezone for testing
    Application.put_env(:open_dev_coach, :timezone, "America/New_York")
    :ok
  end

  describe "local_timezone/0" do
    test "returns configured timezone" do
      assert DateHelper.local_timezone() == "America/New_York"
    end

    test "returns default timezone when not configured" do
      Application.delete_env(:open_dev_coach, :timezone)
      assert DateHelper.local_timezone() == "America/New_York"
    end
  end

  describe "local_datetime_now/0" do
    test "returns current datetime in local timezone" do
      now = DateHelper.local_datetime_now()
      assert %DateTime{} = now
      assert now.time_zone == "America/New_York"

      # Should be close to current time (within 5 seconds)
      current_utc = DateTime.utc_now()
      diff_seconds = abs(DateTime.diff(now, current_utc, :second))
      assert diff_seconds < 5
    end
  end

  describe "next_time_hour_minute/2" do
    test "returns error for invalid hour" do
      assert {:error, "Invalid time: hour must be 0-23, minute must be 0-59"} =
               DateHelper.next_time_hour_minute(24, 30)

      assert {:error, "Invalid time: hour must be 0-23, minute must be 0-59"} =
               DateHelper.next_time_hour_minute(-1, 30)
    end

    test "returns error for invalid minute" do
      assert {:error, "Invalid time: hour must be 0-23, minute must be 0-59"} =
               DateHelper.next_time_hour_minute(12, 60)

      assert {:error, "Invalid time: hour must be 0-23, minute must be 0-59"} =
               DateHelper.next_time_hour_minute(12, -1)
    end

    test "returns valid datetime for valid input with time later than current time" do
      test_now = Timex.DateTime.new!(~D[2025-01-01], ~T[13:00:00], DateHelper.local_timezone())
      {:ok, result} = DateHelper.next_time_hour_minute(14, 30, test_now)

      assert %DateTime{} = result
      assert result.hour == 14
      assert result.minute == 30
      assert result.time_zone == "America/New_York"

      expected_time =
        Timex.DateTime.new!(~D[2025-01-01], ~T[14:30:00], DateHelper.local_timezone())

      assert Timex.equal?(result, expected_time, :minutes)
    end

    test "returns valid datetime for valid input with time earlier than current time" do
      test_now = Timex.DateTime.new!(~D[2025-01-01], ~T[13:00:00], DateHelper.local_timezone())
      {:ok, result} = DateHelper.next_time_hour_minute(12, 30, test_now)

      assert %DateTime{} = result
      assert result.hour == 12
      assert result.minute == 30
      assert result.time_zone == "America/New_York"

      expected_time =
        Timex.DateTime.new!(~D[2025-01-02], ~T[12:30:00], DateHelper.local_timezone())

      assert Timex.equal?(result, expected_time, :minutes)
    end

    test "handles edge cases correctly" do
      test_now = Timex.DateTime.new!(~D[2025-01-01], ~T[13:00:00], DateHelper.local_timezone())

      {:ok, result} = DateHelper.next_time_hour_minute(0, 0, test_now)

      expected_time =
        Timex.DateTime.new!(~D[2025-01-02], ~T[00:00:00], DateHelper.local_timezone())

      assert Timex.equal?(result, expected_time, :minutes)

      {:ok, result} = DateHelper.next_time_hour_minute(23, 59, test_now)

      expected_time =
        Timex.DateTime.new!(~D[2025-01-01], ~T[23:59:00], DateHelper.local_timezone())

      assert Timex.equal?(result, expected_time, :minutes)
    end
  end

  describe "parse_time_format/1" do
    test "parses valid HH:MM format" do
      {:ok, result} = DateHelper.parse_time_format("14:30")

      # Should return next occurrence of 2:30 PM
      assert %DateTime{} = result
      assert result.hour == 14
      assert result.minute == 30
    end

    test "parses single digit hour" do
      {:ok, result} = DateHelper.parse_time_format("9:15")

      assert %DateTime{} = result
      assert result.hour == 9
      assert result.minute == 15
    end

    test "returns error for invalid format" do
      assert {:error, "Invalid time: hour must be 0-23, minute must be 0-59"} =
               DateHelper.parse_time_format("25:30")

      assert {:error, "Invalid time: hour must be 0-23, minute must be 0-59"} =
               DateHelper.parse_time_format("12:60")
    end

    test "returns error for malformed string" do
      assert_raise MatchError, fn ->
        DateHelper.parse_time_format("invalid")
      end
    end

    test "handles edge cases" do
      # Test midnight
      {:ok, result} = DateHelper.parse_time_format("00:00")
      assert result.hour == 0
      assert result.minute == 0

      # Test end of day
      {:ok, result} = DateHelper.parse_time_format("23:59")
      assert result.hour == 23
      assert result.minute == 59
    end
  end

  describe "parse_interval_format/1" do
    test "parses hours only" do
      {:ok, result} = DateHelper.parse_interval_format("2h")

      # Should be current time + 2 hours
      current = DateHelper.local_datetime_now()
      expected = Timex.shift(current, hours: 2)

      assert Timex.equal?(result, expected)
    end

    test "parses minutes only" do
      {:ok, result} = DateHelper.parse_interval_format("30m")

      # Should be current time + 30 minutes
      current = DateHelper.local_datetime_now()
      expected = Timex.shift(current, minutes: 30)

      assert Timex.equal?(result, expected)
    end

    test "parses hours and minutes" do
      {:ok, result} = DateHelper.parse_interval_format("2h 30m")

      # Should be current time + 2 hours 30 minutes
      current = DateHelper.local_datetime_now()
      expected = Timex.shift(current, hours: 2, minutes: 30)

      assert Timex.equal?(result, expected)
    end

    test "parses with different spacing" do
      {:ok, result1} = DateHelper.parse_interval_format("2h30m")
      {:ok, result2} = DateHelper.parse_interval_format("2h 30m")

      assert Timex.equal?(result1, result2)
    end

    test "returns error for zero interval" do
      assert {:error, "Invalid interval: must specify at least one hour or minute"} =
               DateHelper.parse_interval_format("0h 0m")
    end

    test "returns error for invalid format" do
      assert {:error, "Invalid interval: must specify at least one hour or minute"} =
               DateHelper.parse_interval_format("bloop")
    end

    test "handles large intervals" do
      {:ok, result} = DateHelper.parse_interval_format("24h")

      current = DateHelper.local_datetime_now()
      expected = Timex.shift(current, hours: 24)

      assert Timex.equal?(result, expected)
    end
  end

  describe "parse_time_or_interval/1" do
    test "parses HH:MM format" do
      {:ok, result} = DateHelper.parse_time_or_interval("14:30")

      assert %DateTime{} = result
      assert result.hour == 14
      assert result.minute == 30
    end

    test "parses interval format" do
      {:ok, result} = DateHelper.parse_time_or_interval("2h 30m")

      current = DateHelper.local_datetime_now()
      expected = Timex.shift(current, hours: 2, minutes: 30)

      assert Timex.equal?(result, expected)
    end

    test "returns error for unrecognized format" do
      assert {:error, "Invalid format. Use HH:MM (e.g., '09:30') or interval (e.g., '2h 30m')"} =
               DateHelper.parse_time_or_interval("invalid")
    end

    test "returns error for empty string" do
      assert {:error, "Invalid format. Use HH:MM (e.g., '09:30') or interval (e.g., '2h 30m')"} =
               DateHelper.parse_time_or_interval("")
    end

    test "handles various valid formats" do
      # HH:MM formats
      {:ok, result1} = DateHelper.parse_time_or_interval("09:30")
      assert result1.hour == 9
      assert result1.minute == 30

      {:ok, result2} = DateHelper.parse_time_or_interval("23:45")
      assert result2.hour == 23
      assert result2.minute == 45

      # Interval formats
      {:ok, result3} = DateHelper.parse_time_or_interval("1h")
      current = DateHelper.local_datetime_now()
      expected3 = Timex.shift(current, hours: 1)
      assert Timex.equal?(result3, expected3)

      {:ok, result4} = DateHelper.parse_time_or_interval("45m")
      expected4 = Timex.shift(current, minutes: 45)
      assert Timex.equal?(result4, expected4)
    end
  end
end
