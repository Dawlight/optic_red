defmodule OpticRed.Game.State.Data do
  defstruct [
    :lead_team,
    rounds: [],
    teams: [],
    players: %{},
    score: %{},
    words: %{}
  ]
end
