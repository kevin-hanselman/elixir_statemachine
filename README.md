# Elixir State Machine

A simple hierarchical state machine library in Elixir. Written primarily for
educational purposes.

## Usage

Here's an example state machine for a microwave. Nested modules create
hierarchical states.

```elixir
defmodule Microwave do
  defstruct time: 0
  use State

  require Logger

  defmodule Idle do
    use State

    def enter(data) do
      Logger.info("light off")
      data
    end

    def on_event({:key_press, num}, %Microwave{time: t}) when is_number(num) do
      {nil, %Microwave{time: 10 * t + num}}
    end

    # Returning nil for the next state means no transition, a.k.a. an "internal
    # transition".
    def on_event({:key_press, :stop_clear}, _data), do: {nil, %Microwave{time: 0}}

    def on_event({:key_press, :start}, data), do: {Microwave.Running, data}

    defmodule DoorOpen do
      use State

      def enter(data) do
        Logger.info("light on")
        data
      end

      def on_event({:key_press, :start}, data), do: {nil, data}

      def on_event(:close_door, data), do: {Microwave.Idle, data}
    end
  end

  defmodule Running do
    use State

    def enter(data) do
      Logger.info("light on")
      Logger.info("emitter on")
      data
    end

    def exit(data) do
      Logger.info("emitter off")
      data
    end

    def on_event(:tick, %Microwave{time: 1}) do
      Logger.info("done cooking")
      {Microwave.Idle, %Microwave{}}
    end

    def on_event(:tick, %Microwave{time: t}), do: {nil, %Microwave{time: t - 1}}

    def on_event({:key_press, :stop_clear}, data), do: {Microwave.Idle, data}
  end

  def init, do: {Idle, %__MODULE__{}}

  def on_event(:open_door, data), do: {Idle.DoorOpen, data}
end
```

Instantiating the state machine is as easy as starting a `StateMachine`
GenServer with the root `State` module as the initial argument. Then you can
send the state machine events using the GenServer API.

```elixir
# start a Microwave state machine
{:ok, sm} = GenServer.start_link(StateMachine, Microwave)

# print all events and resulting state machine state
:sys.trace(sm, true)

# send events to the microwave
:ok = GenServer.call(sm, {:key_press, 1})

:ok = GenServer.call(sm, {:key_press, 2})

:ok = GenServer.call(sm, {:key_press, :start})

:ok = GenServer.call(sm, :tick)

:ok = GenServer.call(sm, :open_door)
```

## Known bugs/deficiencies

Self-transitions are always external, other transitions are always local. See
[Wikipedia](https://en.wikipedia.org/wiki/UML_state_machine#Local_versus_external_transitions)
for the difference.

No support for [orthogonal
regions](https://en.wikipedia.org/wiki/UML_state_machine#Orthogonal_regions) or
[deferred
events](https://en.wikipedia.org/wiki/UML_state_machine#Event_deferral).

## Installation

```elixir
def deps do
  [
    {:statemachine, git: "https://github.com/kevin-hanselman/elixir_statemachine.git", tag: "main"}
  ]
end
```
