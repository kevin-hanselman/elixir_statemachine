# Elixir State Machine

A simple state machine library in Elixir. Written primarily for educational
purposes.

## Usage

Here's an example state machine for a microwave. This state machine is copied
in `test/test_helper.exs` for testing purposes.

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

    def on_event({:key_press, :stop_clear}, _data), do: {Microwave, nil}
  end

  def init, do: {Idle, %__MODULE__{}}

  def on_event(:open_door, data), do: {Idle.DoorOpen, data}
end
```

## Installation

```elixir
def deps do
  [
    {:statemachine, git: "https://github.com/kevin-hanselman/elixir_statemachine.git", tag: "main"}
  ]
end
```

