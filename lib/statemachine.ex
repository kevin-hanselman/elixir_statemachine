defmodule StateMachine do
  use GenServer

  def init(initial_state) do
    {:ok, transition_state(nil, nil, initial_state)}
  end

  def handle_call(event, _from, {state, data}) do
    {:reply, :ok, handle_event(event, state, data)}
  end

  def handle_cast(event, {state, data}) do
    {:noreply, handle_event(event, state, data)}
  end

  defp handle_event(event, state, data) do
    {new_state, new_data} = state.on_event(event, data)
    transition_state(new_data, state, new_state)
  end

  # initial transition
  defp transition_state(data, _src = nil, dst) do
    data
    |> dst.enter()
    |> process_initial_transitions(dst)
  end

  # no transition
  defp transition_state(data, src, _dst = nil) do
    {src, data}
  end

  # self-transition
  defp transition_state(data, src, dst) when src == dst do
    data
    |> src.exit()
    |> src.enter()
    |> process_initial_transitions(src)
  end

  defp transition_state(data, src, dst) do
    src_parts = Module.split(src)
    dst_parts = Module.split(dst)
    # TODO: this assumes common ancestor, which could always be true if the
    # root module is Elixir
    [{:eq, _lca} | diff] = List.myers_difference(src_parts, dst_parts)

    case diff do
      # exactly one level up
      [{:del, [_one]}] ->
        {dst, src.exit(data)}

      # one or more levels up, with more potential edits
      [{:del, _any} | _more] ->
        data
        |> src.exit()
        |> transition_state(src.parent(), dst)

      # exactly one level down
      [{:ins, [_one]}] ->
        data
        |> dst.enter()
        |> process_initial_transitions(dst)

      # one or more levels down, with more potential edits
      [{:ins, _any} | _more] ->
        child = Enum.slice(dst_parts, 0..-2) |> Module.concat()

        data
        |> child.enter()
        |> transition_state(child, dst)
    end
  end

  defp process_initial_transitions(data, state) do
    case state.init() do
      {nil, _data} -> {state, data}
      {new_state, new_data} -> transition_state(new_data, state, new_state)
    end
  end
end

defmodule State do
  @callback on_event(event :: any(), data :: any()) :: {new_state :: atom(), new_data :: any()}
  @callback enter(data :: any()) :: any()
  @callback exit(data :: any()) :: any()
  @callback init :: {new_state :: atom(), new_data :: any()}
  @callback parent :: atom()

  defmacro __using__(_opts) do
    quote do
      @behaviour State
      @before_compile State

      def enter(data), do: data
      def exit(data), do: data
      def init, do: {nil, nil}

      defoverridable State

      def parent do
        # Use nested modules to show state hierarchy.
        __MODULE__ |> Module.split() |> Enum.slice(0..-2) |> Module.concat()
      end
    end
  end

  # The default event handler for all states needs to be inserted *after*
  # the State's definition (not before, as in __using__), so it doesn't catch all events.
  defmacro __before_compile__(_env) do
    quote do
      def on_event(event, data) do
        case parent() do
          Elixir -> raise "cannot handle event #{event}"
          parent -> parent.on_event(event, data)
        end
      end
    end
  end
end
