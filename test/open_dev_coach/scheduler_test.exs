defmodule OpenDevCoach.SchedulerTest do
  use OpenDevCoach.DataCase, async: false
  alias OpenDevCoach.Scheduler

  describe "time parsing" do
    test "parses HH:MM format correctly" do
      assert {:ok, checkin_id} = Scheduler.add_checkin("09:30", "Morning check-in")
      checkin = OpenDevCoach.Checkins.get_checkin(checkin_id)
      IO.inspect(checkin, label: "---------checkin")
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

    test "provides status information" do
      {:ok, _checkin_id} = Scheduler.add_checkin("12:00", "Status test")
      status = Scheduler.status()
      assert length(status) >= 1

      assert Enum.all?(status, fn s ->
               Map.has_key?(s, :next_occurrence) and
                 Map.has_key?(s, :scheduled_at)
             end)
    end
  end
end
