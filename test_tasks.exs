#!/usr/bin/env elixir

# Simple test script for OpenDevCoach task management
# Run with: elixir test_tasks.exs

# Start the application
Application.ensure_all_started(:open_dev_coach)

# Test task management
alias OpenDevCoach.Session

IO.puts("🧪 Testing OpenDevCoach Task Management...\n")

# Test 1: Add a task
IO.puts("1. Adding a task...")
case Session.add_task("Implement user authentication") do
  {:ok, message} -> IO.puts("✅ #{message}")
  {:error, message} -> IO.puts("❌ #{message}")
end

# Test 2: Add another task
IO.puts("\n2. Adding another task...")
case Session.add_task("Write API documentation") do
  {:ok, message} -> IO.puts("✅ #{message}")
  {:error, message} -> IO.puts("❌ #{message}")
end

# Test 3: List tasks
IO.puts("\n3. Listing tasks...")
case Session.list_tasks() do
  {:ok, message} -> IO.puts("✅ Tasks:\n#{message}")
  {:error, message} -> IO.puts("❌ #{message}")
end

# Test 4: Start first task
IO.puts("\n4. Starting first task...")
case Session.start_task(1) do
  {:ok, message} -> IO.puts("✅ #{message}")
  {:error, message} -> IO.puts("❌ #{message}")
end

# Test 5: List tasks again to see status change
IO.puts("\n5. Listing tasks after starting...")
case Session.list_tasks() do
  {:ok, message} -> IO.puts("✅ Tasks:\n#{message}")
  {:error, message} -> IO.puts("❌ #{message}")
end

# Test 6: Complete first task
IO.puts("\n6. Completing first task...")
case Session.complete_task(1) do
  {:ok, message} -> IO.puts("✅ #{message}")
  {:error, message} -> IO.puts("❌ #{message}")
end

# Test 7: List tasks to see completion
IO.puts("\n7. Listing tasks after completion...")
case Session.list_tasks() do
  {:ok, message} -> IO.puts("✅ Tasks:\n#{message}")
  {:error, message} -> IO.puts("❌ #{message}")
end

# Test 8: Backup tasks
IO.puts("\n8. Creating task backup...")
case Session.backup_tasks() do
  {:ok, message} -> IO.puts("✅ #{message}")
  {:error, message} -> IO.puts("❌ #{message}")
end

# Test 9: Remove second task
IO.puts("\n9. Removing second task...")
case Session.remove_task(2) do
  {:ok, message} -> IO.puts("✅ #{message}")
  {:error, message} -> IO.puts("❌ #{message}")
end

# Test 10: Final task list
IO.puts("\n10. Final task list...")
case Session.list_tasks() do
  {:ok, message} -> IO.puts("✅ Tasks:\n#{message}")
  {:error, message} -> IO.puts("❌ #{message}")
end

IO.puts("\n🎉 Task management testing completed!")
