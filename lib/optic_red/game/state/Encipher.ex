defmodule OpticRed.Game.State.Encipher do
  alias OpticRed.Game.Model.Data
  defstruct data: %Data{}

  use OpticRed.Game.State

  alias OpticRed.Game.ActionResult

  alias OpticRed.Game.Model.Round

  alias OpticRed.Game.Event.{
    CluesSubmitted,
    AllCluesSubmitted
  }

  alias OpticRed.Game.Action.{
    SubmitClues
  }

  alias OpticRed.Game.State.Decipher

  #
  # Action handlers
  #

  def handle_action(%__MODULE__{data: data}, %SubmitClues{team_id: team_id, clues: clues}) do
    %Data{teams: teams} = data

    current_round = data |> Data.get_round(0)
    other_teams = teams |> Enum.filter(fn team -> team.id != team_id end)

    last_submit? =
      other_teams
      |> Enum.all?(fn team ->
        current_round |> Round.get_clues(team.id) != nil
      end)

    case current_round |> Round.get_clues(team_id) do
      nil ->
        action_result = ActionResult.new([CluesSubmitted.with(team_id: team_id, clues: clues)])

        case last_submit? do
          true ->
            action_result
            |> ActionResult.add([AllCluesSubmitted.empty()])

          false ->
            action_result
        end

      _ ->
        ActionResult.empty()
    end
  end

  #
  # Event application
  #

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
