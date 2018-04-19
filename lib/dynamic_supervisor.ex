defmodule ManagerSupervisor.DynamicSupervisor do
  use DynamicSupervisor

  def child_spec(opts) do
    mod = Keyword.fetch!(opts, :mod)
    arg = Keyword.fetch!(opts, :arg)
    %{
      id: __MODULE__,
      start: {DynamicSupervisor, :start_link, [__MODULE__, {mod, arg}, opts]},
      type: :supervisor
    }
  end

  def start_child(name, spec) do
    DynamicSupervisor.start_child({:via, Registry, {name, __MODULE__}}, spec)
  end

  @impl true
  def init({mod, arg}) do
    mod.supervisor_init(arg)
  end
end
