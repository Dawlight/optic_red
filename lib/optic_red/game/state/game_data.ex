defmodule OpticRed.Game.State.Data do
  defstruct [
    :lead_team_id,
    :target_score,
    rounds: [],
    teams: [],
    team_map: %{},
    player_map: %{},
    player_team_map: %{},
    team_words_map: %{},
    team_score_map: %{},
    ready_players: []
  ]
end
