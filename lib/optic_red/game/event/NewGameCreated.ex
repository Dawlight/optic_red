defmodule OpticRed.Game.Event.NewGameCreated do
  defstruct teams: [], players: [], player_team_map: [], target_points: 2
  use OpticRed.Game.Event
end

# def create_new(teams, players, player_team_map, target_points \\ 2) do
