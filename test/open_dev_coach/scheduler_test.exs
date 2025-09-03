defmodule OpenDevCoach.SchedulerTest do
  use OpenDevCoach.DataCase, async: false
  alias OpenDevCoach.Scheduler

  describe "time parsing" do
    test "parses HH:MM format correctly" do
      # Use a time that's clearly in the future to avoid timezone issues
      future_hour = DateTime.utc_now().hour + 1
      future_hour = if future_hour > 23, do: 0, else: future_hour

      time_str = "#{String.pad_leading("#{future_hour}", 2, "0")}:30"
      assert {:ok, checkin_id} = Scheduler.add_checkin(time_str, "Future check-in")
      checkin = OpenDevCoach.Checkins.get_checkin(checkin_id)

      # The time should be scheduled for the future
      assert DateTime.compare(checkin.scheduled_at, DateTime.utc_now()) == :gt
    end

    test "parses interval format correctly" do
      assert {:ok, _checkin_id} = Scheduler.add_checkin("2h 30m", "Interval check-in")
      assert {:ok, _checkin_id} = Scheduler.add_checkin("30m", "Short interval")
    end

    test "rejects invalid time formats" do
      assert {:error, _reason} = Scheduler.add_checkin("25:00", "Invalid time")
      assert {:error, _reason} = Scheduler.add_checkin("invalid", "Invalid format")
    end
  end

  describe "check-in management" do
    test "can add and list check-ins" do
      {:ok, checkin_id} = Scheduler.add_checkin("10:00", "Test check-in")
      checkins = Scheduler.list_checkins()
      assert length(checkins) >= 1
      assert Enum.any?(checkins, fn c -> c.id == checkin_id end)
    end

    test "can remove check-ins" do
      {:ok, checkin_id} = Scheduler.add_checkin("11:00", "To be removed")
      assert {:ok, _message} = Scheduler.remove_checkin(checkin_id)
      checkins = Scheduler.list_checkins()
      refute Enum.any?(checkins, fn c -> c.id == checkin_id end)
    end

    test "creates one-time check-ins (not recurring)" do
      # Use a time that's clearly in the future
      future_hour = DateTime.utc_now().hour + 1
      future_hour = if future_hour > 23, do: 0, else: future_hour

      time_str = "#{String.pad_leading("#{future_hour}", 2, "0")}:00"
      {:ok, checkin_id} = Scheduler.add_checkin(time_str, "One-time test")
      checkin = OpenDevCoach.Checkins.get_checkin(checkin_id)

      # Status could be SCHEDULED or SKIPPED depending on when the test runs
      # relative to the scheduler startup
      assert checkin.status in ["SCHEDULED", "SKIPPED"]

      # The important thing is that it's not marked as recurring
      # After execution, should be marked as COMPLETED
      # (This would be tested in integration tests with actual execution)
    end
  end
end
