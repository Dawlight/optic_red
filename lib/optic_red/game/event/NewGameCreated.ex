defmodule OpticRed.Game.Event.NewGameCreated do
  defstruct teams: [], players: [], player_team_map: [], target_score: 2
  use OpticRed.Game.Event
end

# def create_new(teams, players, player_team_map, target_score \\ 2) do
