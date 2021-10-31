defmodule OpticRed.Game.State.Decipher do
  alias OpticRed.Game.Model.Data

  defstruct data: %Data{},
            lead_team: nil,
            remaining_lead_teams: []

  use OpticRed.Game.State

  alias OpticRed.Game.Model.Round
  alias OpticRed.Game.Event.AttemptSubmitted
  alias OpticRed.Game.State.{RoundEnd, GameEnd}

  def new(%Data{teams: teams} = data) do
    [lead_team | remaining_lead_teams] = teams

    where(
      data: data,
      lead_team: lead_team,
      remaining_lead_teams: remaining_lead_teams
    )
  end

  def apply_event(%__MODULE__{} = state, %AttemptSubmitted{} = event) do
    %__MODULE__{
      data: data,
      lead_team: lead_team
    } = state

    %AttemptSubmitted{team_id: team_id, attempt: attempt} = event

    data = data |> Data.update_round(0, &Round.set_attempt(&1, team_id, lead_team.id, attempt))
    state = state |> where(data: data)

    with {:continue, state} <- check_submissions(state),
         {:continue, state} <- check_turns(state),
         {:continue, state} <- update_score(state),
         {:next, state} <- check_win(state) do
      state
    else
      {:next, state} -> state
    end
  end

  defp check_submissions(%__MODULE__{} = state) do
    if all_teams_submitted?(state) do
      {:continue, state}
    else
      {:next, state}
    end
  end

  defp all_teams_submitted?(%__MODULE__{data: data, lead_team: lead_team} = state) do
    %Data{teams: teams} = data

    teams
    |> Enum.all?(fn team ->
      data
      |> Data.get_round(0)
      |> Round.get_attempt(team.id, lead_team.id) != nil
    end)
  end

  def update_score(%__MODULE__{data: data} = state) do
    %Data{score_by_team_id: score_by_team_id, teams: teams} = data

    round_score_by_team_id = data |> Data.get_round(0) |> Round.get_score(teams)

    score_by_team_id =
      Map.merge(score_by_team_id, round_score_by_team_id, fn _, score, round_score ->
        score + round_score
      end)

    data = data |> Data.where(score_by_team_id: score_by_team_id)
    {:continue, state |> where(data: data)}
  end

  def check_turns(%__MODULE__{remaining_lead_teams: remaining_lead_teams} = state) do
    case remaining_lead_teams do
      [] ->
        {:continue, state}

      [next_lead_team | remaining_lead_teams] ->
        state =
          state
          |> where(
            lead_team: next_lead_team,
            remaining_lead_teams: remaining_lead_teams
          )

        {:next, state}
    end
  end

  def check_win(%__MODULE__{data: data} = state) do
    case any_team_won?(data) do
      true ->
        {:next, GameEnd.new(data)}

      false ->
        {:next, RoundEnd.new(data)}
    end
  end

  defp any_team_won?(%Data{} = data) do
    %Data{teams: teams, target_score: target_score} = data

    teams |> Enum.any?(fn team -> data |> Data.get_score(team) >= target_score end)
  end
end
