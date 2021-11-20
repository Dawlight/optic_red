defmodule OpticRed.Game.State.Rules.Encipher do
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

  alias OpticRed.Game.State.Rules.Decipher

  #
  # Action handlers
  #

  def new(data) do
    %Data{teams: teams} = data

    {encipherer_by_team_id, data} =
      teams
      |> List.foldl({%{}, data}, fn team, {encipherer_by_team_id, data} ->
        {encipherer, data} = data |> Data.pop_random_encipherer(team)
        {encipherer_by_team_id |> Map.put(team.id, encipherer), data}
      end)

    code_by_team_id = for team <- teams, into: %{}, do: {team.id, get_random_code()}

    new_round =
      Round.empty()
      |> Round.with_default_attempts(teams)
      |> Round.with_default_clues(teams)
      |> Round.with_encipherers(encipherer_by_team_id)
      |> Round.with_codes(code_by_team_id)

    data = data |> Data.add_round(new_round)

    where(data: data)
  end

  defp get_random_code(), do: Enum.take_random(1..4, 3)

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

    state |> where(data: data)
  end

  def apply_event(%__MODULE__{data: data}, %AllCluesSubmitted{}) do
    Decipher.new(data)
  end
end
