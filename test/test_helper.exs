ExUnit.start()

# Start the Ecto repo for tests
{:ok, _} = Application.ensure_all_started(:open_dev_coach)
