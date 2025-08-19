defmodule OpenDevCoachTest do
  use ExUnit.Case
  doctest OpenDevCoach

  test "greets the world" do
    assert OpenDevCoach.hello() == :world
  end
end
