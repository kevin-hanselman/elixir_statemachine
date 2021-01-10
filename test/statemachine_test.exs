defmodule State.Test do
  use ExUnit.Case

  test "state handles event" do
    m = %Microwave{}
    out = Microwave.Idle.on_event({:key_press, 3}, m)
    assert out == {nil, %Microwave{time: 3}}
  end

  test "state delegates event to parent" do
    m = %Microwave{}
    out = Microwave.Running.on_event(:open_door, m)
    assert out == {Microwave.Idle.DoorOpen, m}
  end
end

defmodule StateMachine.Test do
  use ExUnit.Case

  require Logger

  setup do
    Logger.configure([level: :warn])
    {:ok, sm} = GenServer.start_link(StateMachine, Microwave)
    %{sm: sm}
  end

  test "follows initial transitions", %{sm: sm} do
    assert :sys.get_state(sm) == {Microwave.Idle, %Microwave{time: 0}}
  end

  test "handle events", %{sm: sm} do
    :ok = GenServer.call(sm, {:key_press, 1})
    assert :sys.get_state(sm) == {Microwave.Idle, %Microwave{time: 1}}

    :ok = GenServer.call(sm, {:key_press, 2})
    assert :sys.get_state(sm) == {Microwave.Idle, %Microwave{time: 12}}

    :ok = GenServer.call(sm, {:key_press, :stop_clear})
    assert :sys.get_state(sm) == {Microwave.Idle, %Microwave{time: 0}}

    :ok = GenServer.call(sm, {:key_press, 2})
    assert :sys.get_state(sm) == {Microwave.Idle, %Microwave{time: 2}}

    :ok = GenServer.call(sm, {:key_press, :start})
    assert :sys.get_state(sm) == {Microwave.Running, %Microwave{time: 2}}

    :ok = GenServer.call(sm, :tick)
    assert :sys.get_state(sm) == {Microwave.Running, %Microwave{time: 1}}

    :ok = GenServer.call(sm, :open_door)
    assert :sys.get_state(sm) == {Microwave.Idle.DoorOpen, %Microwave{time: 1}}

    :ok = GenServer.call(sm, {:key_press, :start})
    assert :sys.get_state(sm) == {Microwave.Idle.DoorOpen, %Microwave{time: 1}}

    :ok = GenServer.call(sm, :close_door)
    assert :sys.get_state(sm) == {Microwave.Idle, %Microwave{time: 1}}

    :ok = GenServer.call(sm, {:key_press, :start})
    assert :sys.get_state(sm) == {Microwave.Running, %Microwave{time: 1}}

    :ok = GenServer.call(sm, :tick)
    assert :sys.get_state(sm) == {Microwave.Idle, %Microwave{time: 0}}
  end
end
