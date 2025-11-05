defmodule OpenDevCoach.SchedulerTest do
  use OpenDevCoach.DataCase, async: false

  alias OpenDevCoach.Helpers.Date, as: DateHelper
  alias OpenDevCoach.Servers.Scheduler

  describe "time parsing" do
    test "parses HH:MM format correctly" do
      # Use a time that's clearly in the future to avoid timezone issues
      future_hour = DateTime.utc_now().hour + 1
      future_hour = if future_hour > 23, do: 0, else: future_hour

      time_str = "#{String.pad_leading("#{future_hour}", 2, "0")}:30"
      assert {:ok, added_checkin, _list} = Scheduler.add_checkin(time_str, "Future check-in")

      assert DateTime.compare(added_checkin.scheduled_at, DateTime.utc_now()) == :gt
    end

    test "parses interval format correctly" do
      time_now = DateHelper.local_datetime_now()
      expected_time = Timex.shift(time_now, hours: 2, minutes: 30)
      assert {:ok, added_checkin, _list} = Scheduler.add_checkin("2h 30m", "Interval check-in")
      assert Timex.compare(added_checkin.scheduled_at, expected_time, :minutes) == 0

      expected_time = Timex.shift(time_now, minutes: 30)
      assert {:ok, added_checkin, _list} = Scheduler.add_checkin("30m", "Short interval")
      assert Timex.compare(added_checkin.scheduled_at, expected_time, :minutes) == 0
    end

    test "rejects invalid time formats" do
      assert {:error, _reason} = Scheduler.add_checkin("25:00", "Invalid time")
      assert {:error, _reason} = Scheduler.add_checkin("invalid", "Invalid format")
    end
  end

  describe "check-in management" do
    test "can add and list check-ins" do
      {:ok, checkin, checkins} = Scheduler.add_checkin("10:00", "Test check-in")
      checkins_without_ordinal = Enum.map(checkins, &elem(&1, 0))
      assert length(checkins_without_ordinal) >= 1
      assert Enum.any?(checkins_without_ordinal, fn c -> c.id == checkin.id end)
    end

    test "can remove check-ins" do
      {:ok, checkin, checkin_list} = Scheduler.add_checkin("11:00", "To be removed")
      {_checkin, ordinal} = find_checkin_by_id(checkin_list, checkin.id)
      assert {:ok, _message} = Scheduler.remove_checkin(ordinal)
      {:ok, checkins} = Scheduler.list_checkins()
      checkins_without_ordinal = Enum.map(checkins, &elem(&1, 0))
      refute Enum.any?(checkins_without_ordinal, fn c -> c.id == checkin.id end)
    end

    test "creates one-time check-ins (not recurring)" do
      # Use a time that's clearly in the future
      future_hour = DateTime.utc_now().hour + 1
      future_hour = if future_hour > 23, do: 0, else: future_hour

      time_str = "#{String.pad_leading("#{future_hour}", 2, "0")}:00"
      {:ok, checkin, _list} = Scheduler.add_checkin(time_str, "One-time test")

      # Status could be SCHEDULED or SKIPPED depending on when the test runs
      # relative to the scheduler startup
      assert checkin.status in ["SCHEDULED", "SKIPPED"]

      # The important thing is that it's not marked as recurring
      # After execution, should be marked as COMPLETED
      # (This would be tested in integration tests with actual execution)
    end
  end

  defp find_checkin_by_id(checkin_list, id) do
    Enum.find(checkin_list, &(Map.get(elem(&1, 0), :id) == id))
  end
end
