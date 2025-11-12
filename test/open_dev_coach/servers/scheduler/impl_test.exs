defmodule OpenDevCoach.Servers.Scheduler.ImplTest do
  use OpenDevCoach.DataCase, async: false

  alias OpenDevCoach.Servers.Scheduler.Impl
  alias OpenDevCoach.Checkins
  alias OpenDevCoach.Checkins.Checkin
  alias OpenDevCoach.Helpers.Date, as: DateHelper

  describe "init/1" do
    test "initializes scheduler state with proper structure" do
      # This test will use the actual modules since we're testing the implementation
      # The init function calls external modules, so we'll test the structure
      state = Impl.init([])

      assert is_map(state)
      assert is_list(state.checkins)
      assert is_list(state.timers)
    end
  end

  describe "add_checkin/3" do
    setup do
      base_state = %{
        checkins: [],
        timers: []
      }

      %{state: base_state}
    end

    test "adds a new check-in with time format", %{state: state} do
      {{:ok, checkin, list_of_sorted_checkins}, new_state} =
        Impl.add_checkin(state, "14:30", "Test check-in")

      assert length(new_state.checkins) == 1
      assert hd(new_state.checkins).description == "Test check-in"
      assert hd(new_state.checkins).status == "SCHEDULED"
      assert length(list_of_sorted_checkins) == 1
      {returned_checkin, _ordinal} = hd(list_of_sorted_checkins)
      assert returned_checkin.description == "Test check-in"
      assert returned_checkin.id == checkin.id
    end

    test "adds a new check-in with interval format", %{state: state} do
      {{:ok, checkin, list_of_sorted_checkins}, new_state} =
        Impl.add_checkin(state, "2h 30m", "Interval check-in")

      assert length(new_state.checkins) == 1
      assert hd(new_state.checkins).description == "Interval check-in"
      assert hd(new_state.checkins).status == "SCHEDULED"
      assert length(list_of_sorted_checkins) == 1
      {returned_checkin, _ordinal} = hd(list_of_sorted_checkins)
      assert returned_checkin.description == "Interval check-in"
      assert returned_checkin.id == checkin.id
    end

    test "adds a new check-in without description", %{state: state} do
      {{:ok, checkin, list_of_sorted_checkins}, new_state} =
        Impl.add_checkin(state, "09:15")

      assert length(new_state.checkins) == 1
      assert hd(new_state.checkins).description == nil
      assert hd(new_state.checkins).status == "SCHEDULED"
      assert length(list_of_sorted_checkins) == 1
      {returned_checkin, _ordinal} = hd(list_of_sorted_checkins)
      assert returned_checkin.id == checkin.id
    end

    test "returns error for invalid time format", %{state: state} do
      {{:error, reason}, returned_state} = Impl.add_checkin(state, "invalid")

      assert reason =~ "Invalid format"
      assert returned_state == state
    end

    test "returns error for invalid interval", %{state: state} do
      {{:error, reason}, returned_state} = Impl.add_checkin(state, "0h 0m")

      assert reason =~ "Invalid interval"
      assert returned_state == state
    end

    test "adds multiple check-ins and sorts them correctly", %{state: state} do
      # Add check-ins in non-chronological order
      {{:ok, _checkin1, _}, state1} = Impl.add_checkin(state, "15:00", "Third")
      {{:ok, _checkin2, _}, state2} = Impl.add_checkin(state1, "09:00", "First")
      {{:ok, _checkin3, _}, state3} = Impl.add_checkin(state2, "12:00", "Second")

      {{:ok, sorted_checkins}, _final_state} = Impl.list_checkins(state3)

      assert length(sorted_checkins) == 3
      {first, 1} = Enum.at(sorted_checkins, 0)
      {second, 2} = Enum.at(sorted_checkins, 1)
      {third, 3} = Enum.at(sorted_checkins, 2)

      assert first.description == "First"
      assert second.description == "Second"
      assert third.description == "Third"

      # Verify they're sorted by scheduled_at
      assert DateTime.compare(first.scheduled_at, second.scheduled_at) == :lt
      assert DateTime.compare(second.scheduled_at, third.scheduled_at) == :lt
    end
  end

  describe "list_checkins/1" do
    test "returns empty list for empty check-in list" do
      state = %{checkins: [], timers: []}
      {{:ok, checkins}, returned_state} = Impl.list_checkins(state)

      assert checkins == []
      assert returned_state == state
    end

    test "returns check-in list with ordinals" do
      now = DateHelper.local_datetime_now()

      checkin_list = [
        %Checkin{
          id: Ecto.UUID.generate(),
          scheduled_at: Timex.shift(now, hours: 3),
          status: "SCHEDULED",
          description: "First check-in"
        },
        %Checkin{
          id: Ecto.UUID.generate(),
          scheduled_at: Timex.shift(now, hours: 2),
          status: "SCHEDULED",
          description: "Second check-in"
        },
        %Checkin{
          id: Ecto.UUID.generate(),
          scheduled_at: Timex.shift(now, hours: 1),
          status: "SCHEDULED",
          description: "Third check-in"
        }
      ]

      state = %{checkins: checkin_list, timers: []}

      {{:ok, checkins}, returned_state} = Impl.list_checkins(state)

      assert length(checkins) == 3
      # Check-ins are sorted by scheduled_at ascending (earliest first)
      {checkin, ordinal} = hd(checkins)
      assert checkin.description == "Third check-in"
      assert ordinal == 1
      assert returned_state == state
    end

    test "returns check-ins sorted by scheduled_at" do
      now = DateHelper.local_datetime_now()

      checkin_list = [
        %Checkin{
          id: Ecto.UUID.generate(),
          scheduled_at: Timex.shift(now, hours: 5),
          status: "SCHEDULED",
          description: "Latest"
        },
        %Checkin{
          id: Ecto.UUID.generate(),
          scheduled_at: Timex.shift(now, hours: 1),
          status: "SCHEDULED",
          description: "Earliest"
        },
        %Checkin{
          id: Ecto.UUID.generate(),
          scheduled_at: Timex.shift(now, hours: 3),
          status: "SCHEDULED",
          description: "Middle"
        }
      ]

      state = %{checkins: checkin_list, timers: []}

      {{:ok, checkins}, _returned_state} = Impl.list_checkins(state)

      assert length(checkins) == 3
      {earliest, 1} = Enum.at(checkins, 0)
      {middle, 2} = Enum.at(checkins, 1)
      {latest, 3} = Enum.at(checkins, 2)

      assert earliest.description == "Earliest"
      assert middle.description == "Middle"
      assert latest.description == "Latest"
    end
  end

  describe "remove_checkin/2" do
    setup do
      now = DateHelper.local_datetime_now()

      {:ok, checkin1} =
        Checkins.create_checkin(%{
          id: Ecto.UUID.generate(),
          scheduled_at: Timex.shift(now, hours: 3),
          status: "SCHEDULED",
          description: "Check-in 1"
        })

      {:ok, checkin2} =
        Checkins.create_checkin(%{
          id: Ecto.UUID.generate(),
          scheduled_at: Timex.shift(now, hours: 2),
          status: "SCHEDULED",
          description: "Check-in 2"
        })

      {:ok, checkin3} =
        Checkins.create_checkin(%{
          id: Ecto.UUID.generate(),
          scheduled_at: Timex.shift(now, hours: 1),
          status: "SCHEDULED",
          description: "Check-in 3"
        })

      checkins = [checkin1, checkin2, checkin3]
      state = %{checkins: checkins, timers: []}
      %{state: state}
    end

    test "removes a check-in by ordinal number", %{state: state} do
      {{:ok, message}, new_state} = Impl.remove_checkin(state, 2)

      assert message == "Check-in removed"
      assert length(new_state.checkins) == 2
      # Ordinal 2 is the second check-in in sorted order (Check-in 2)
      # Remaining check-ins should be Check-in 1 and Check-in 3
      sorted_checkins =
        new_state.checkins |> Enum.sort_by(& &1.scheduled_at)

      assert length(sorted_checkins) == 2
      assert Enum.at(sorted_checkins, 0).description == "Check-in 3"
      assert Enum.at(sorted_checkins, 1).description == "Check-in 1"
    end

    test "removes first check-in by ordinal", %{state: state} do
      {{:ok, message}, new_state} = Impl.remove_checkin(state, 1)

      assert message == "Check-in removed"
      assert length(new_state.checkins) == 2
      # Ordinal 1 is the earliest check-in (Check-in 3)
      sorted_checkins =
        new_state.checkins |> Enum.sort_by(& &1.scheduled_at)

      assert length(sorted_checkins) == 2
      assert Enum.at(sorted_checkins, 0).description == "Check-in 2"
      assert Enum.at(sorted_checkins, 1).description == "Check-in 1"
    end

    test "returns error for invalid task ordinal (zero)", %{state: state} do
      {{:error, reason}, returned_state} = Impl.remove_checkin(state, 0)

      assert reason == "Invalid checkin ordinal"
      assert returned_state == state
    end

    test "returns error for check-in ordinal out of range", %{state: state} do
      {{:error, reason}, returned_state} = Impl.remove_checkin(state, 10)

      assert reason == "Check-in not found"
      assert returned_state == state
    end

    test "returns error for negative ordinal", %{state: state} do
      {{:error, reason}, returned_state} = Impl.remove_checkin(state, -1)

      assert reason == "Invalid checkin ordinal"
      assert returned_state == state
    end
  end

  describe "handle_checkin_trigger/2" do
    setup do
      now = DateHelper.local_datetime_now()

      {:ok, checkin} =
        Checkins.create_checkin(%{
          id: Ecto.UUID.generate(),
          scheduled_at: Timex.shift(now, hours: -1),
          status: "SCHEDULED",
          description: "Test check-in"
        })

      state = %{checkins: [checkin], timers: []}
      %{state: state, checkin: checkin}
    end

    test "handles check-in trigger and updates status", %{state: state, checkin: checkin} do
      result = Impl.handle_checkin_trigger(state, checkin.id)
      {updated_checkin, new_state} = result

      assert updated_checkin.status == "COMPLETED"
      assert updated_checkin.last_triggered_at != nil
      assert is_map(new_state)
      assert length(new_state.checkins) == 1
      updated_state_checkin = hd(new_state.checkins)
      assert updated_state_checkin.status == "COMPLETED"
      assert updated_state_checkin.id == checkin.id
    end

    test "returns state unchanged when check-in not found", %{state: state} do
      non_existent_id = Ecto.UUID.generate()
      {returned_state1, returned_state2} = Impl.handle_checkin_trigger(state, non_existent_id)

      assert returned_state1 == state
      assert returned_state2 == state
      assert length(returned_state1.checkins) == 1
      assert hd(returned_state1.checkins).status == "SCHEDULED"
    end

    test "handles multiple check-ins and triggers correct one" do
      now = DateHelper.local_datetime_now()

      {:ok, checkin1} =
        Checkins.create_checkin(%{
          id: Ecto.UUID.generate(),
          scheduled_at: Timex.shift(now, hours: 1),
          status: "SCHEDULED",
          description: "Check-in 1"
        })

      {:ok, checkin2} =
        Checkins.create_checkin(%{
          id: Ecto.UUID.generate(),
          scheduled_at: Timex.shift(now, hours: 2),
          status: "SCHEDULED",
          description: "Check-in 2"
        })

      state_with_multiple = %{checkins: [checkin1, checkin2], timers: []}
      {updated_checkin, new_state} = Impl.handle_checkin_trigger(state_with_multiple, checkin1.id)

      assert updated_checkin.id == checkin1.id
      assert updated_checkin.status == "COMPLETED"
      assert length(new_state.checkins) == 2

      # Verify checkin1 is updated but checkin2 is not
      updated_checkin1 = Enum.find(new_state.checkins, &(&1.id == checkin1.id))
      updated_checkin2 = Enum.find(new_state.checkins, &(&1.id == checkin2.id))

      assert updated_checkin1.status == "COMPLETED"
      assert updated_checkin2.status == "SCHEDULED"
    end
  end
end
