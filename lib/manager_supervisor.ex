defmodule ManagerSupervisor do
  @type child_spec :: :supervisor.child_spec() | {module, term} | module

  @callback supervisor_init(arg :: term()) :: {:ok, DynamicSupervisor.sup_flags()} | :ignore

  @callback manager_init(arg :: term()) ::
              {:ok, state}
              | {:ok, state, timeout() | :hibernate}
              | :ignore
              | {:stop, reason :: any()}
            when state: any()

  @callback terminate(reason, state :: term()) :: term()
            when reason: :normal | :shutdown | {:shutdown, term()}

  @callback child_terminated(pid(), reason, state :: term()) ::
              {:noreply, new_state}
              | {:noreply, new_state, timeout() | :hibername}
              | {:stop, reason :: term(), new_state}
            when new_state: term(), reason: term()

  @callback child_started(pid(), state :: term()) ::
              {:noreply, new_state}
              | {:noreply, new_state, timeout() | :hibernate}
              | {:stop, reason :: term(), new_state}
            when new_state: term()

  @callback handle_info(msg :: :timeout | term(), state :: term()) ::
              {:noreply, new_state}
              | {:noreply, new_state, timeout() | :hibernate}
              | {:stop, reason :: term(), new_state}
              | {:start_child, child_spec(), new_state}
            when new_state: term()

  @callback handle_cast(request :: term(), state :: term()) ::
              {:noreply, new_state}
              | {:noreply, new_state, timeout() | :hibernate}
              | {:stop, reason :: term(), new_state}
              | {:start_child, child_spec(), new_state}
            when new_state: term()

  @callback handle_call(request :: term(), GenServer.from(), state :: term) ::
              {:reply, reply, new_state}
              | {:reply, reply, new_state, timeout() | :hibernate}
              | {:noreply, new_state}
              | {:noreply, new_state, timeout() | :hibernate}
              | {:stop, reason, reply, new_state}
              | {:stop, reason, new_state}
              | {:start_child, child_spec(), new_state}
              | {:start_child, child_spec(), reply, new_state}
            when reply: term, new_state: term, reason: term

  @callback code_change(old_vsn, state :: term(), extra :: term()) ::
              {:ok, new_state :: term()}
              | {:error, reason :: term()}
              | {:down, term()}
            when old_vsn: term()

  @callback format_status(reason, pdict_and_state :: list()) :: term()
            when reason: :normal | :terminate

  @optional_callbacks format_status: 2

  alias ManagerSupervisor.{Manager, DynamicSupervisor}

  def start_link(mod, name, arg, opts \\ []) do
    Supervisor.start_link(__MODULE__, {mod, name, arg}, opts)
  end

  def init({mod, name, arg}) do
    children = [
      {Registry, keys: :unique, name: name},
      {DynamicSupervisor, mod: mod, arg: arg, name: {:via, Registry, {name, DynamicSupervisor}}},
      {Manager, mod: mod, arg: {arg, self()}, name: {:via, Registry, {name, Manager}}}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
