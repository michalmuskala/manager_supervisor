defmodule ManagerSupervisor.Manager do
  use GenServer

  alias ManagerSupervisor.DynamicSupervisor

  def child_spec(opts) do
    mod = Keyword.fetch!(opts, :mod)
    arg = Keyword.fetch!(opts, :arg)

    %{
      id: __MODULE__,
      start: {GenServer, :start_link, [__MODULE__, {mod, arg}, opts]}
    }
  end

  @impl true
  def init({mod, arg}) do
    try do
      mod.manager_init(arg)
    catch
      :throw, value -> exit({{:nocatch, value}, System.stacktrace()})
    else
      {:ok, inner} -> {:ok, %{inner: inner, mod: mod, children: %{}}}
      {:ok, inner, timeout} -> {:ok, %{inner: inner, mod: mod, children: %{}}, timeout}
      other -> other
    end
  end

  @impl true
  def handle_call(msg, from, %{mod: mod, inner: inner} = state) do
    try do
      mod.handle_call(msg, from, inner)
    catch
      :throw, value -> exit({{:nocatch, value}, System.stacktrace()})
    else
      {:reply, reply, inner} -> {:reply, reply, %{state | inner: inner}}
      {:reply, reply, inner, timeout} -> {:reply, reply, %{state | inner: inner}, timeout}
      {:noreply, inner} -> {:noreply, %{state | inner: inner}}
      {:noreply, inner, timeout} -> {:noreply, %{state | inner: inner}, timeout}
      {:stop, reason, reply, inner} -> {:stop, reason, reply, %{state | inner: inner}}
      {:stop, reason, inner} -> {:stop, reason, %{state | inner: inner}}
      {:start_child, spec, inner} -> start_child(spec, mod, inner, state)
      {:start_child, spec, reply, inner} -> start_child_reply(spec, mod, inner, state, reply)
    end
  end

  defp start_child_reply(spec, mod, inner, state, reply) do
    case start_child(spec, mod, inner, state) do
      {:noreply, state} -> {:reply, reply, state}
      {:noreply, state, timeout} -> {:reply, reply, state, timeout}
      {:stop, reason, state} -> {:stop, reason, reply, state}
    end
  end

  @impl true
  def handle_info({:DOWN, ref, _, pid, reason} = msg, state) do
    %{mod: mod, inner: inner, children: children} = state

    case children do
      %{^ref => :ok} ->
        children = Map.delete(children, ref)

        try do
          mod.child_terminated(pid, reason, inner)
        catch
          :throw, value -> exit({{:nocatch, value}, System.stacktrace()})
        else
          {:noreply, inner} ->
            {:noreply, %{state | inner: inner, children: children}}

          {:noreply, inner, timeout} ->
            {:noreply, %{state | inner: inner, children: children}, timeout}

          {:stop, reason, inner} ->
            {:stop, reason, %{state | inner: inner, children: children}}
        end

      %{} ->
        generic_info(msg, state)
    end
  end

  def handle_info(msg, state) do
    generic_info(msg, state)
  end

  defp generic_info(msg, %{inner: inner, mod: mod} = state) do
    try do
      mod.handle_info(msg, inner)
    catch
      :throw, value -> exit({{:nocatch, value}, System.stacktrace()})
    else
      {:noreply, inner} -> {:noreply, %{state | inner: inner}}
      {:noreply, inner, timeout} -> {:noreply, %{state | inner: inner}, timeout}
      {:stop, reason, inner} -> {:stop, reason, %{state | inner: inner}}
      {:start_child, spec, inner} -> start_child(spec, mod, inner, state)
      other -> {:stop, {:bad_return_value, other}, %{state | inner: inner}}
    end
  end

  @impl true
  def code_change(old, %{mod: mod, inner: inner} = state, extra) do
    try do
      mod.code_change(old, inner, extra)
    catch
      :throw, value -> exit({{:nocatch, value}, System.stacktrace()})
    else
      {:ok, inner} -> {:ok, %{state | inner: inner}}
    end
  end

  @impl true
  def format_status(:normal, [pdict, %{mod: mod, inner: inner}]) do
    try do
      apply(mod, :format_status, [:normal, [pdict, inner]])
    catch
      _, _ -> [{:data, [{'State', inner}]}]
    else
      mod_status -> mod_status
    end
  end

  def format_status(:terminate, [pdict, %{mod: mod, inner: inner}]) do
    try do
      apply(mod, :format_status, [:terminate, [pdict, inner]])
    catch
      _, _ -> inner
    else
      mod_state -> mod_state
    end
  end

  defp start_child(spec, mod, inner, %{name: name} = state) do
    # TODO: return stop tuple and terminate nicely
    case DynamicSupervisor.start_child(name, spec) do
      {:ok, pid} -> child_started(pid, mod, inner, state)
      {:ok, pid, _info} -> child_started(pid, mod, inner, state)
      {:error, error} -> {:stop, {:cannot_start, error}, %{state | inner: inner}}
    end
  end

  defp child_started(pid, mod, inner, %{children: children} = state) do
    ref = Process.monitor(pid)

    try do
      mod.child_started(pid, inner)
    catch
      :throw, value -> exit({{:nocatch, value}, System.stacktrace()})
    else
      {:noreply, inner} ->
        {:noreply, %{state | inner: inner, children: Map.put(children, ref, :ok)}}

      {:noreply, inner, timeout} ->
        {:noreply, %{state | inner: inner, children: Map.put(children, ref, :ok)}, timeout}

      {:stop, reason, inner} ->
        {:stop, reason, %{state | inner: inner, children: Map.put(children, ref, :ok)}}
    end
  end
end
