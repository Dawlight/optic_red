defmodule OpticRed.Game.Event.AttemptSubmitted do
  defstruct [:decipherer_team_id, :encipherer_team_id, :attempt]
  use OpticRed.Game.Event
end

# def create_new(teams, players, player_team_map, target_points \\ 2) do
