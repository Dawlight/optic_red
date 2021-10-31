defmodule OpticRed.Game.State.Encipher do
  alias OpticRed.Game.State.Data
  defstruct data: %Data{}

  use OpticRed.Game.State

  alias OpticRed.Game.State.Round
  alias OpticRed.Game.State.Decipher

  alias OpticRed.Game.Event.CluesSubmitted

  def apply_event(%__MODULE__{data: data} = state, %CluesSubmitted{team_id: team_id, clues: clues}) do
    data = data |> Data.update_round(0, &Round.set_clues(&1, team_id, clues))

    if all_clues_submitted?(data) do
      Decipher.new(data)
    else
      state |> where(data: data)
    end
  end

  defp all_clues_submitted?(%Data{teams: teams} = data) do
    teams
    |> Enum.all?(fn team ->
      data
      |> Data.get_round(0)
      |> Round.get_clues(team.id) != nil
    end)
  end
end
