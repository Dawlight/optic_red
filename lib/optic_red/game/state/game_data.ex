defmodule OpticRed.Game.State.Data do
  defstruct [
    :lead_team,
    :target_score,
    rounds: [],
    teams: [],
    players: %{},
    score: %{},
    words: %{}
  ]
end
