defmodule OpticRed.Game.Action.ReadyPlayer do
  defstruct [:player_id, :ready?]
  use OpticRed.Game.Action
end
