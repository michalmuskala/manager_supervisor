defmodule ManagerSupervisorTest do
  use ExUnit.Case
  doctest ManagerSupervisor

  test "greets the world" do
    assert ManagerSupervisor.hello() == :world
  end
end
