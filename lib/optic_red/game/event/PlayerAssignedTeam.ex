defmodule OpticRed.Game.Event.PlayerAssignedTeam do
  defstruct [:player_id, :team_id]
  use OpticRed.Game.Event
end
