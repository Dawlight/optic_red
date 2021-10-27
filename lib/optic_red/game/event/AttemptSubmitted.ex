defmodule OpticRed.Game.Event.AttemptSubmitted do
  defstruct [:team_id, :attempt]
  use OpticRed.Game.Event
end

# def create_new(teams, players, player_team_map, target_score \\ 2) do
