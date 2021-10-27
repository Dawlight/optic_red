defmodule OpticRed.Game.Event.PlayerReadied do
  defstruct [:player_id, ready?: true]
  use OpticRed.Game.Event
end

# def set_player_ready(%__MODULE__{data: data, current: current} = state, player_id, ready?) do
