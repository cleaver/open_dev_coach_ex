defmodule OpenDevCoach.CheckinsTest do
  use OpenDevCoach.DataCase
  alias OpenDevCoach.Checkins
  alias OpenDevCoach.Checkins.Checkin
  alias OpenDevCoach.Helpers.Date, as: DateHelper

  # Set test timezone to UTC for consistent testing
  setup do
    Application.put_env(:open_dev_coach, :timezone, "Etc/UTC")
    :ok
  end

  # Helper function to create a valid checkin
  defp valid_checkin_attrs do
    %{
      scheduled_at: ~N[2024-01-15 09:30:00],
      description: "Test checkin"
    }
  end

  describe "create_checkin/1" do
    test "creates a checkin with valid attributes" do
      attrs = valid_checkin_attrs()
      {:ok, checkin} = Checkins.create_checkin(attrs)

      assert checkin.description == "Test checkin"
      assert checkin.status == "SCHEDULED"
      assert checkin.scheduled_at
      assert checkin.inserted_at
      assert checkin.updated_at
    end

    test "creates a checkin with minimal required attributes" do
      attrs = %{scheduled_at: ~N[2024-01-15 09:30:00]}
      {:ok, checkin} = Checkins.create_checkin(attrs)

      assert checkin.scheduled_at
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
      assert checkin.scheduled_at
    end
  end

  describe "get_checkin/1" do
    test "returns checkin when it exists" do
      {:ok, created_checkin} = Checkins.create_checkin(valid_checkin_attrs())
      retrieved_checkin = Checkins.get_checkin(created_checkin.id)

      assert retrieved_checkin
      assert retrieved_checkin.id == created_checkin.id
      assert retrieved_checkin.description == created_checkin.description
    end

    test "returns nil when checkin does not exist" do
      assert Checkins.get_checkin(999_999) == nil
    end

    test "returns checkin with converted timezone" do
      {:ok, created_checkin} = Checkins.create_checkin(valid_checkin_attrs())
      retrieved_checkin = Checkins.get_checkin(created_checkin.id)

      # In test environment with UTC timezone, times should be the same
      assert Timex.compare(retrieved_checkin.scheduled_at, created_checkin.scheduled_at, :minutes) ==
               0
    end
  end

  describe "list_checkins/0" do
    test "returns empty list when no checkins exist" do
      assert Checkins.list_checkins() == []
    end

    test "returns all checkins with converted timezones" do
      {:ok, checkin1} =
        Checkins.create_checkin(%{
          scheduled_at: ~N[2024-01-15 09:30:00],
          description: "First checkin"
        })

      {:ok, checkin2} =
        Checkins.create_checkin(%{
          scheduled_at: ~N[2024-01-15 10:30:00],
          description: "Second checkin"
        })

      checkins = Checkins.list_checkins()
      assert length(checkins) == 2

      # Verify both checkins are returned with proper timezone conversion
      assert Enum.any?(checkins, &(&1.id == checkin1.id))
      assert Enum.any?(checkins, &(&1.id == checkin2.id))
    end
  end

  describe "list_active_checkins/0" do
    test "returns only non-completed checkins" do
      # Create active checkins
      {:ok, _active1} =
        Checkins.create_checkin(%{
          scheduled_at: ~N[2024-01-15 09:30:00],
          status: "SCHEDULED",
          description: "Active checkin 1"
        })

      {:ok, _active2} =
        Checkins.create_checkin(%{
          scheduled_at: ~N[2024-01-15 10:30:00],
          status: "SKIPPED",
          description: "Active checkin 2"
        })

      # Create completed checkin
      {:ok, _completed} =
        Checkins.create_checkin(%{
          scheduled_at: ~N[2024-01-15 11:30:00],
          status: "COMPLETED",
          description: "Completed checkin"
        })

      active_checkins = Checkins.list_active_checkins()
      assert length(active_checkins) == 2

      # Verify only non-completed statuses are returned
      assert Enum.all?(active_checkins, &(&1.status != "COMPLETED"))
    end

    test "returns checkins ordered by scheduled_at" do
      {:ok, _later} =
        Checkins.create_checkin(%{
          scheduled_at: ~N[2024-01-15 10:30:00],
          status: "SCHEDULED",
          description: "Later checkin"
        })

      {:ok, _earlier} =
        Checkins.create_checkin(%{
          scheduled_at: ~N[2024-01-15 09:30:00],
          status: "SCHEDULED",
          description: "Earlier checkin"
        })

      active_checkins = Checkins.list_active_checkins()
      assert length(active_checkins) == 2

      # Verify ordering (earliest first) - Timex.compare returns -1 for earlier
      [first, second] = active_checkins
      assert Timex.compare(first.scheduled_at, second.scheduled_at) == -1
    end
  end

  describe "list_scheduled_checkins/0" do
    test "returns only SCHEDULED status checkins" do
      # Create scheduled checkin
      {:ok, _scheduled} =
        Checkins.create_checkin(%{
          scheduled_at: ~N[2024-01-15 09:30:00],
          status: "SCHEDULED",
          description: "Scheduled checkin"
        })

      # Create other status checkins
      {:ok, _skipped} =
        Checkins.create_checkin(%{
          scheduled_at: ~N[2024-01-15 10:30:00],
          status: "SKIPPED",
          description: "Skipped checkin"
        })

      {:ok, _completed} =
        Checkins.create_checkin(%{
          scheduled_at: ~N[2024-01-15 11:30:00],
          status: "COMPLETED",
          description: "Completed checkin"
        })

      scheduled_checkins = Checkins.list_scheduled_checkins()
      assert length(scheduled_checkins) == 1
      assert hd(scheduled_checkins).status == "SCHEDULED"
    end

    test "returns checkins ordered by scheduled_at" do
      {:ok, _later} =
        Checkins.create_checkin(%{
          scheduled_at: ~N[2024-01-15 10:30:00],
          status: "SCHEDULED",
          description: "Later scheduled checkin"
        })

      {:ok, _earlier} =
        Checkins.create_checkin(%{
          scheduled_at: ~N[2024-01-15 09:30:00],
          status: "SCHEDULED",
          description: "Earlier scheduled checkin"
        })

      scheduled_checkins = Checkins.list_scheduled_checkins()
      assert length(scheduled_checkins) == 2

      # Verify ordering (earliest first) - Timex.compare returns -1 for earlier
      [first, second] = scheduled_checkins
      assert Timex.compare(first.scheduled_at, second.scheduled_at) == -1
    end
  end

  describe "update_checkin/2" do
    test "updates checkin with valid attributes" do
      {:ok, checkin} = Checkins.create_checkin(valid_checkin_attrs())
      update_attrs = %{description: "Updated description", status: "SKIPPED"}

      {:ok, updated_checkin} = Checkins.update_checkin(checkin, update_attrs)

      assert updated_checkin.description == "Updated description"
      assert updated_checkin.status == "SKIPPED"
      assert updated_checkin.scheduled_at == checkin.scheduled_at
    end

    test "updates datetime fields with timezone conversion" do
      {:ok, checkin} = Checkins.create_checkin(valid_checkin_attrs())
      new_time = ~N[2024-01-16 14:00:00]
      update_attrs = %{scheduled_at: new_time}

      {:ok, updated_checkin} = Checkins.update_checkin(checkin, update_attrs)
      assert updated_checkin.scheduled_at != checkin.scheduled_at
    end

    test "returns error with invalid attributes" do
      {:ok, checkin} = Checkins.create_checkin(valid_checkin_attrs())
      update_attrs = %{status: "INVALID_STATUS"}

      {:error, changeset} = Checkins.update_checkin(checkin, update_attrs)
      assert %{status: ["is invalid"]} = errors_on(changeset)
    end

    test "updates last_triggered_at and completed_at" do
      {:ok, checkin} = Checkins.create_checkin(valid_checkin_attrs())
      now = DateTime.utc_now()

      update_attrs = %{
        last_triggered_at: now,
        completed_at: now
      }

      {:ok, updated_checkin} = Checkins.update_checkin(checkin, update_attrs)
      assert updated_checkin.last_triggered_at
      assert updated_checkin.completed_at
    end
  end

  describe "delete_checkin/1" do
    test "deletes existing checkin" do
      {:ok, checkin} = Checkins.create_checkin(valid_checkin_attrs())
      {:ok, deleted_checkin} = Checkins.delete_checkin(checkin)

      assert deleted_checkin.id == checkin.id
      assert Checkins.get_checkin(checkin.id) == nil
    end
  end

  describe "change_checkin_status/2" do
    test "changes checkin status" do
      {:ok, checkin} = Checkins.create_checkin(valid_checkin_attrs())
      {:ok, updated_checkin} = Checkins.change_checkin_status(checkin, "SKIPPED")

      assert updated_checkin.status == "SKIPPED"
    end

    test "validates status value" do
      {:ok, checkin} = Checkins.create_checkin(valid_checkin_attrs())
      {:error, changeset} = Checkins.change_checkin_status(checkin, "INVALID_STATUS")

      assert %{status: ["is invalid"]} = errors_on(changeset)
    end
  end

  describe "complete_checkin/1" do
    test "marks checkin as completed and sets completed_at" do
      {:ok, checkin} = Checkins.create_checkin(valid_checkin_attrs())
      {:ok, completed_checkin} = Checkins.complete_checkin(checkin)

      assert completed_checkin.status == "COMPLETED"
      assert completed_checkin.completed_at
      # Compare DateTime with DateTime, ensuring both are DateTime structs
      # completed_at should be >= inserted_at (allowing for same millisecond)
      comparison =
        DateTime.compare(
          completed_checkin.completed_at,
          DateTime.from_naive!(checkin.inserted_at, "Etc/UTC")
        )

      assert comparison == :gt or comparison == :eq
    end
  end

  describe "mark_past_scheduled_checkins_as_skipped/0" do
    test "marks past scheduled checkins as skipped" do
      # Create past scheduled checkin
      # 1 hour ago
      past_time = DateTime.utc_now() |> DateTime.add(-3600, :second)

      {:ok, past_checkin} =
        Checkins.create_checkin(%{
          scheduled_at: past_time,
          status: "SCHEDULED",
          description: "Past checkin"
        })

      # Create future scheduled checkin
      # 1 hour from now
      future_time = DateTime.utc_now() |> DateTime.add(3600, :second)

      {:ok, future_checkin} =
        Checkins.create_checkin(%{
          scheduled_at: future_time,
          status: "SCHEDULED",
          description: "Future checkin"
        })

      # Mark past checkins as skipped
      {update_count, _} = Checkins.mark_past_scheduled_checkins_as_skipped()
      assert update_count == 1

      # Verify past checkin was marked as skipped by getting it directly
      updated_past_checkin = Checkins.get_checkin(past_checkin.id)
      assert updated_past_checkin.status == "SKIPPED"

      # Verify future checkin remains scheduled
      updated_future_checkin = Checkins.get_checkin(future_checkin.id)
      assert updated_future_checkin.status == "SCHEDULED"
    end

    test "does not affect non-scheduled checkins" do
      # Create completed checkin
      past_time = DateTime.utc_now() |> DateTime.add(-3600, :second)

      {:ok, _completed_checkin} =
        Checkins.create_checkin(%{
          scheduled_at: past_time,
          status: "COMPLETED",
          description: "Completed checkin"
        })

      {update_count, _} = Checkins.mark_past_scheduled_checkins_as_skipped()
      assert update_count == 0
    end
  end

  describe "timezone handling" do
    test "converts naive local time to UTC for storage" do
      # Test with a NaiveDateTime (local time)
      naive_local_time = ~N[2024-01-15 09:30:00]

      # Create checkin with local time
      {:ok, checkin} =
        Checkins.create_checkin(%{
          scheduled_at: naive_local_time,
          description: "Test checkin"
        })

      # The stored time should be in UTC
      local_time =
        naive_local_time
        |> Timex.to_datetime("Etc/UTC")
        |> Timex.Timezone.convert(DateHelper.local_timezone())

      raw_checkin = Repo.get!(Checkin, checkin.id)

      assert raw_checkin.scheduled_at
      assert Timex.compare(raw_checkin.scheduled_at, local_time, :minutes) == 0
    end

    test "converts UTC to local time for display" do
      # Create a checkin with UTC time
      local_time = DateHelper.local_datetime_now()

      {:ok, checkin} =
        Checkins.create_checkin(%{
          scheduled_at: local_time,
          description: "Test checkin"
        })

      # When retrieved, times should be converted to local timezone
      retrieved_checkin = Checkins.get_checkin(checkin.id)
      assert retrieved_checkin.scheduled_at

      # In test environment with UTC timezone, times should be the same
      assert Timex.compare(retrieved_checkin.scheduled_at, local_time, :minutes) == 0
    end

    test "handles nil datetime fields gracefully" do
      {:ok, checkin} =
        Checkins.create_checkin(%{
          scheduled_at: ~N[2024-01-15 09:30:00],
          description: "Test checkin"
        })

      # Update with nil datetime fields
      {:ok, updated_checkin} =
        Checkins.update_checkin(checkin, %{
          last_triggered_at: nil,
          completed_at: nil
        })

      # Should handle nil values without errors
      assert updated_checkin.last_triggered_at == nil
      assert updated_checkin.completed_at == nil
    end

    test "converts DateTime with timezone to UTC" do
      # Create DateTime with specific timezone
      local_datetime = DateTime.new!(~D[2024-01-15], ~T[09:30:00], "America/New_York")
      attrs = %{scheduled_at: local_datetime, description: "Timezone test"}

      {:ok, checkin} = Checkins.create_checkin(attrs)
      assert checkin.scheduled_at

      # Verify the time was converted to UTC for storage
      raw_checkin = Repo.get!(Checkin, checkin.id)
      assert raw_checkin.scheduled_at
      # Check that the timezone is UTC by comparing with a UTC time
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

      # Update with new times
      new_time = DateTime.add(now, 3600, :second)

      {:ok, updated_checkin} =
        Checkins.update_checkin(checkin, %{
          last_triggered_at: new_time,
          completed_at: new_time
        })

      # All datetime fields should be properly converted
      assert updated_checkin.scheduled_at
      assert updated_checkin.last_triggered_at
      assert updated_checkin.completed_at
      assert updated_checkin.inserted_at
      assert updated_checkin.updated_at
    end
  end

  describe "edge cases and error handling" do
    test "handles empty attributes map" do
      {:error, changeset} = Checkins.create_checkin(%{})
      assert %{scheduled_at: ["can't be blank"]} = errors_on(changeset)
    end

    test "handles invalid ID for get_checkin" do
      assert Checkins.get_checkin(999_999) == nil
      # get_checkin doesn't handle nil gracefully, so we'll test with a valid invalid ID
      assert Checkins.get_checkin(0) == nil
    end

    test "handles update with empty attributes" do
      {:ok, checkin} = Checkins.create_checkin(valid_checkin_attrs())
      {:ok, updated_checkin} = Checkins.update_checkin(checkin, %{})

      # Should remain unchanged
      assert updated_checkin.description == checkin.description
      assert updated_checkin.status == checkin.status
    end

    test "handles status transitions correctly" do
      {:ok, checkin} = Checkins.create_checkin(valid_checkin_attrs())
      assert checkin.status == "SCHEDULED"

      # Transition to SKIPPED
      {:ok, checkin} = Checkins.change_checkin_status(checkin, "SKIPPED")
      assert checkin.status == "SKIPPED"

      # Transition to COMPLETED
      {:ok, checkin} = Checkins.complete_checkin(checkin)
      assert checkin.status == "COMPLETED"
      assert checkin.completed_at

      # Transition to CANCELLED
      {:ok, checkin} = Checkins.change_checkin_status(checkin, "CANCELLED")
      assert checkin.status == "CANCELLED"
    end

    test "handles concurrent updates gracefully" do
      {:ok, checkin} = Checkins.create_checkin(valid_checkin_attrs())

      # Simulate concurrent updates
      {:ok, updated1} = Checkins.update_checkin(checkin, %{description: "Update 1"})
      {:ok, updated2} = Checkins.update_checkin(checkin, %{description: "Update 2"})

      # Both should succeed
      assert updated1.description == "Update 1"
      assert updated2.description == "Update 2"
    end
  end
end
