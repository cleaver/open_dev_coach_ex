defmodule OpenDevCoach.CheckinsTest do
  alias OpenDevCoach.CheckinFixtures
  use OpenDevCoach.DataCase
  alias OpenDevCoach.Checkins
  alias OpenDevCoach.Checkins.Checkin
  alias OpenDevCoach.Helpers.Date, as: DateHelper

  defp valid_checkin_attrs do
    %{
      scheduled_at: ~N[2024-01-15 09:30:00],
      description: "Test checkin"
    }
  end

  describe "create_checkin/1" do
    test "creates a checkin with valid attributes" do
      attrs = %{
        scheduled_at: DateHelper.local_datetime_now() |> Timex.shift(hours: 2),
        description: "Test checkin"
      }

      {:ok, checkin} = Checkins.create_checkin(attrs)

      assert checkin.description == "Test checkin"
      assert checkin.status == "SCHEDULED"
      assert checkin.scheduled_at |> Timex.compare(attrs.scheduled_at, :minutes) == 0
      assert checkin.inserted_at
      assert checkin.updated_at
    end

    test "creates a checkin with minimal required attributes" do
      attrs = %{
        scheduled_at: DateHelper.local_datetime_now() |> Timex.shift(hours: 2)
      }

      {:ok, checkin} = Checkins.create_checkin(attrs)

      assert checkin.scheduled_at |> Timex.compare(attrs.scheduled_at, :minutes) == 0
      assert checkin.status == "SCHEDULED"
      assert checkin.description == nil
    end

    test "creates a checkin with all attributes" do
      attrs = %{
        scheduled_at: ~N[2024-01-15 09:30:00],
        status: "COMPLETED",
        description: "Full checkin",
        last_triggered_at: ~N[2024-01-15 10:00:00],
        completed_at: ~N[2024-01-15 10:30:00]
      }

      {:ok, checkin} = Checkins.create_checkin(attrs)

      assert checkin.description == "Full checkin"
      assert checkin.status == "COMPLETED"
      assert checkin.scheduled_at
      assert checkin.last_triggered_at
      assert checkin.completed_at
    end

    test "returns error with invalid attributes" do
      attrs = %{description: "Missing scheduled_at"}
      {:error, changeset} = Checkins.create_checkin(attrs)

      assert %{scheduled_at: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns error with invalid status" do
      attrs = %{
        scheduled_at: ~N[2024-01-15 09:30:00],
        status: "INVALID_STATUS"
      }

      {:error, changeset} = Checkins.create_checkin(attrs)
      assert %{status: ["is invalid"]} = errors_on(changeset)
    end

    test "creates checkin with DateTime input" do
      datetime = DateTime.new!(~D[2024-01-15], ~T[09:30:00], "Etc/UTC")
      attrs = %{scheduled_at: datetime, description: "DateTime checkin"}

      {:ok, checkin} = Checkins.create_checkin(attrs)
      assert checkin.description == "DateTime checkin"
      assert checkin.scheduled_at |> Timex.compare(attrs.scheduled_at, :minutes) == 0
    end
  end

  describe "get_checkin/1" do
    setup [:scheduled_checkin]

    test "returns checkin when it exists", %{scheduled_checkin: scheduled_checkin} do
      retrieved_checkin = Checkins.get_checkin(scheduled_checkin.id)

      assert retrieved_checkin
      assert retrieved_checkin.id == scheduled_checkin.id
      assert retrieved_checkin.description == scheduled_checkin.description
    end

    test "returns nil when checkin does not exist" do
      assert Checkins.get_checkin(999_999) == nil
    end

    test "returns checkin with converted timezone" do
      created_checkin = CheckinFixtures.checkin_fixture(%{scheduled_at: Timex.now()})
      retrieved_checkin = Checkins.get_checkin(created_checkin.id)

      assert retrieved_checkin.scheduled_at.time_zone == DateHelper.local_timezone()

      assert Timex.compare(retrieved_checkin.scheduled_at, created_checkin.scheduled_at, :minutes) ==
               0
    end
  end

  describe "list_checkins/0" do
    setup [:scheduled_checkin, :completed_checkin, :skipped_checkin]

    test "returns all scheduled checkins with converted timezones",
         %{
           scheduled_checkin: scheduled_checkin,
           completed_checkin: completed_checkin,
           skipped_checkin: skipped_checkin
         } do
      checkins = Checkins.list_checkins()

      assert length(checkins) == 3

      assert Enum.any?(checkins, &(&1.id == scheduled_checkin.id))
      assert scheduled_checkin.scheduled_at.time_zone == DateHelper.local_timezone()
      assert Enum.any?(checkins, &(&1.id == skipped_checkin.id))
      assert skipped_checkin.scheduled_at.time_zone == DateHelper.local_timezone()
      assert Enum.any?(checkins, &(&1.id == completed_checkin.id))
      assert completed_checkin.completed_at.time_zone == DateHelper.local_timezone()
    end
  end

  describe "list_active_checkins/0" do
    setup [:scheduled_checkin, :completed_checkin, :skipped_checkin]

    test "returns only scheduled checkins" do
      future_time = DateHelper.local_datetime_now() |> Timex.shift(hours: 2)

      _additional_checkin = CheckinFixtures.checkin_fixture(%{scheduled_at: future_time})

      active_checkins = Checkins.list_active_checkins()
      assert length(active_checkins) == 2

      assert Enum.all?(active_checkins, &(&1.status == "SCHEDULED"))
    end

    test "returns checkins ordered by scheduled_at" do
      future_time = DateHelper.local_datetime_now() |> Timex.shift(hours: 5)

      _additional_checkin = CheckinFixtures.checkin_fixture(%{scheduled_at: future_time})

      active_checkins = Checkins.list_active_checkins()
      assert length(active_checkins) == 2

      [first, second] = active_checkins
      assert Timex.compare(first.scheduled_at, second.scheduled_at) == -1
    end
  end

  describe "list_scheduled_checkins/0" do
    setup [:scheduled_checkin, :completed_checkin, :skipped_checkin]

    test "returns only SCHEDULED status checkins" do
      scheduled_checkins = Checkins.list_scheduled_checkins()
      assert length(scheduled_checkins) == 1
      assert hd(scheduled_checkins).status == "SCHEDULED"
    end

    test "returns checkins ordered by scheduled_at" do
      future_time = DateHelper.local_datetime_now() |> Timex.shift(hours: 5)

      _additional_checkin = CheckinFixtures.checkin_fixture(%{scheduled_at: future_time})

      scheduled_checkins = Checkins.list_scheduled_checkins()
      assert length(scheduled_checkins) == 2

      [first, second] = scheduled_checkins
      assert Timex.compare(first.scheduled_at, second.scheduled_at) == -1
    end
  end

  describe "update_checkin/2" do
    setup [:scheduled_checkin]

    test "updates checkin with valid attributes", %{scheduled_checkin: scheduled_checkin} do
      update_attrs = %{description: "Updated description", status: "SKIPPED"}

      {:ok, updated_checkin} = Checkins.update_checkin(scheduled_checkin, update_attrs)

      assert updated_checkin.description == "Updated description"
      assert updated_checkin.status == "SKIPPED"

      assert Timex.compare(updated_checkin.scheduled_at, scheduled_checkin.scheduled_at, :minutes) ==
               0
    end

    test "updates datetime fields with timezone conversion", %{
      scheduled_checkin: scheduled_checkin
    } do
      new_time = DateHelper.local_datetime_now() |> Timex.shift(hours: 7)
      update_attrs = %{scheduled_at: new_time}

      {:ok, updated_checkin} = Checkins.update_checkin(scheduled_checkin, update_attrs)

      assert Timex.compare(updated_checkin.scheduled_at, scheduled_checkin.scheduled_at, :minutes) !=
               0
    end

    test "returns error with invalid attributes", %{scheduled_checkin: scheduled_checkin} do
      update_attrs = %{status: "INVALID_STATUS"}

      {:error, changeset} = Checkins.update_checkin(scheduled_checkin, update_attrs)
      assert %{status: ["is invalid"]} = errors_on(changeset)
    end

    test "updates last_triggered_at and completed_at", %{scheduled_checkin: scheduled_checkin} do
      now = DateHelper.local_datetime_now()

      update_attrs = %{
        last_triggered_at: now,
        completed_at: now
      }

      {:ok, updated_checkin} = Checkins.update_checkin(scheduled_checkin, update_attrs)
      assert Timex.compare(updated_checkin.last_triggered_at, now, :minutes) == 0
      assert Timex.compare(updated_checkin.completed_at, now, :minutes) == 0
    end
  end

  describe "delete_checkin/1" do
    setup [:scheduled_checkin]

    test "deletes existing checkin", %{scheduled_checkin: scheduled_checkin} do
      {:ok, deleted_checkin} = Checkins.delete_checkin(scheduled_checkin)

      assert deleted_checkin.id == scheduled_checkin.id
      assert Checkins.get_checkin(scheduled_checkin.id) == nil
    end
  end

  describe "change_checkin_status/2" do
    setup [:scheduled_checkin]

    test "changes checkin status", %{scheduled_checkin: scheduled_checkin} do
      {:ok, updated_checkin} = Checkins.change_checkin_status(scheduled_checkin, "SKIPPED")

      assert updated_checkin.status == "SKIPPED"
    end

    test "validates status value", %{scheduled_checkin: scheduled_checkin} do
      {:error, changeset} = Checkins.change_checkin_status(scheduled_checkin, "INVALID_STATUS")

      assert %{status: ["is invalid"]} = errors_on(changeset)
    end
  end

  describe "complete_checkin/1" do
    setup [:scheduled_checkin]

    test "marks checkin as completed and sets completed_at", %{
      scheduled_checkin: scheduled_checkin
    } do
      {:ok, completed_checkin} = Checkins.complete_checkin(scheduled_checkin)

      assert completed_checkin.status == "COMPLETED"
      assert completed_checkin.completed_at
    end
  end

  describe "mark_past_scheduled_checkins_as_skipped/0" do
    setup [:scheduled_checkin, :completed_checkin]

    test "marks past scheduled checkins as skipped", %{scheduled_checkin: scheduled_checkin} do
      past_time = DateHelper.local_datetime_now() |> Timex.shift(hours: -1)

      past_checkin =
        CheckinFixtures.checkin_fixture(%{
          scheduled_at: past_time,
          status: "SCHEDULED",
          description: "Past checkin"
        })

      {update_count, _} = Checkins.mark_past_scheduled_checkins_as_skipped()
      assert update_count == 1

      updated_past_checkin = Checkins.get_checkin(past_checkin.id)
      assert updated_past_checkin.status == "SKIPPED"

      updated_scheduled_checkin = Checkins.get_checkin(scheduled_checkin.id)
      assert updated_scheduled_checkin.status == "SCHEDULED"
    end
  end

  describe "timezone handling" do
    test "converts naive local time to UTC for storage" do
      naive_local_time = ~N[2024-01-15 09:30:00]

      {:ok, checkin} =
        Checkins.create_checkin(%{
          scheduled_at: naive_local_time,
          description: "Test checkin"
        })

      local_time = Timex.to_datetime(naive_local_time, DateHelper.local_timezone())

      raw_checkin = Repo.get!(Checkin, checkin.id)

      assert raw_checkin.scheduled_at
      assert Timex.compare(raw_checkin.scheduled_at, local_time, :minutes) == 0
    end

    test "handles nil datetime fields gracefully" do
      {:ok, checkin} =
        Checkins.create_checkin(%{
          scheduled_at: ~N[2024-01-15 09:30:00],
          description: "Test checkin"
        })

      {:ok, updated_checkin} =
        Checkins.update_checkin(checkin, %{
          last_triggered_at: nil,
          completed_at: nil
        })

      assert updated_checkin.last_triggered_at == nil
      assert updated_checkin.completed_at == nil
    end

    test "converts DateTime with timezone to UTC" do
      local_datetime = DateTime.new!(~D[2024-01-15], ~T[09:30:00], "America/New_York")
      attrs = %{scheduled_at: local_datetime, description: "Timezone test"}

      {:ok, checkin} = Checkins.create_checkin(attrs)
      assert checkin.scheduled_at

      raw_checkin = Repo.get!(Checkin, checkin.id)
      assert raw_checkin.scheduled_at
      assert raw_checkin.scheduled_at.time_zone == "Etc/UTC"
      assert DateTime.compare(raw_checkin.scheduled_at, DateTime.utc_now()) == :lt
    end

    test "preserves timezone conversion across all datetime fields" do
      now = DateTime.utc_now()

      {:ok, checkin} =
        Checkins.create_checkin(%{
          scheduled_at: now,
          last_triggered_at: now,
          completed_at: now,
          description: "All datetime fields test"
        })

      new_time = DateHelper.local_datetime_now() |> Timex.shift(hours: 1)

      {:ok, updated_checkin} =
        Checkins.update_checkin(checkin, %{
          last_triggered_at: new_time,
          completed_at: new_time
        })

      assert updated_checkin.scheduled_at.time_zone == DateHelper.local_timezone()
      assert updated_checkin.last_triggered_at.time_zone == DateHelper.local_timezone()
      assert updated_checkin.completed_at.time_zone == DateHelper.local_timezone()
    end
  end

  describe "edge cases and error handling" do
    test "handles empty attributes map" do
      {:error, changeset} = Checkins.create_checkin(%{})
      assert %{scheduled_at: ["can't be blank"]} = errors_on(changeset)
    end

    test "handles invalid ID for get_checkin" do
      assert Checkins.get_checkin(999_999) == nil
      assert Checkins.get_checkin(0) == nil
    end

    test "handles update with empty attributes" do
      {:ok, checkin} = Checkins.create_checkin(valid_checkin_attrs())
      {:ok, updated_checkin} = Checkins.update_checkin(checkin, %{})

      assert updated_checkin.description == checkin.description
      assert updated_checkin.status == checkin.status
    end

    test "handles status transitions correctly" do
      {:ok, checkin} = Checkins.create_checkin(valid_checkin_attrs())
      assert checkin.status == "SCHEDULED"

      {:ok, checkin} = Checkins.change_checkin_status(checkin, "SKIPPED")
      assert checkin.status == "SKIPPED"

      {:ok, checkin} = Checkins.complete_checkin(checkin)
      assert checkin.status == "COMPLETED"
      assert checkin.completed_at

      {:ok, checkin} = Checkins.change_checkin_status(checkin, "CANCELLED")
      assert checkin.status == "CANCELLED"
    end
  end

  defp scheduled_checkin(_) do
    %{scheduled_checkin: CheckinFixtures.checkin_fixture()}
  end

  defp completed_checkin(_) do
    %{completed_checkin: CheckinFixtures.completed_checkin_fixture()}
  end

  defp skipped_checkin(_) do
    %{skipped_checkin: CheckinFixtures.skipped_checkin_fixture()}
  end
end
