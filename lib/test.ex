defmodule Test do
  @behaviour ManagerSupervisor

  def supervisor_init(_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def manager_init(arg) do
    {:ok, arg}
  end
end
