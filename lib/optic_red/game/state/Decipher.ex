defmodule OpticRed.Game.State.Decipher do
  alias OpticRed.Game.Model.Data

  defstruct data: %Data{},
            lead_team: nil,
            remaining_lead_teams: []

  use OpticRed.Game.State

  alias OpticRed.Game.Model.Round

  alias OpticRed.Game.ActionResult

  alias OpticRed.Game.Event.{
    AttemptSubmitted,
    ScoreIncremented,
    StrikeIncremented,
    LeadTeamPassed,
    RoundEnded,
    GameEnded,
    TeamWon,
    TeamLost
  }

  alias OpticRed.Game.Action.{SubmitAttempt}
  alias OpticRed.Game.State.{RoundEnd, GameEnd}

  def new(%Data{teams: teams} = data) do
    [lead_team | remaining_lead_teams] = teams

    where(
      data: data,
      lead_team: lead_team,
      remaining_lead_teams: remaining_lead_teams
    )
  end

  #
  # Action handler
  #

  def handle_action(%__MODULE__{} = state, %SubmitAttempt{} = action) do
    action_result = ActionResult.new([])

    with {:continue, action_result} <- check_valid_submission(state, action, action_result),
         {:continue, action_result} <- check_scoring(state, action, action_result),
         {:continue, action_result} <- check_last_submission(state, action, action_result),
         {:continue, action_result} <- check_remaining_lead_teams(state, action, action_result),
         {:continue, action_result} <- check_game_end(state, action, action_result) do
      action_result
    else
      {:break, action_result} -> action_result
    end
  end

  #
  # Action handler private
  #

  defp check_valid_submission(%__MODULE__{} = state, %SubmitAttempt{} = action, action_result) do
    %__MODULE__{lead_team: lead_team} = state
    %SubmitAttempt{team_id: team_id, attempt: attempt} = action

    case teams_without_submission(state) |> Enum.member?(team_id) do
      false ->
        {:break, action_result}

      true ->
        {:continue,
         action_result
         |> ActionResult.add([
           AttemptSubmitted.with(
             deciphering_team_id: team_id,
             enciphering_team_id: lead_team.id,
             attempt: attempt
           )
         ])}
    end
  end

  defp check_scoring(%__MODULE__{} = state, %SubmitAttempt{} = action, action_result) do
    %SubmitAttempt{team_id: team_id} = action

    action_result =
      cond do
        should_receive_point?(state, action) ->
          action_result |> ActionResult.add([ScoreIncremented.with(team_id: team_id)])

        should_receive_strike?(state, action) ->
          action_result |> ActionResult.add([StrikeIncremented.with(team_id: team_id)])

        true ->
          action_result
      end

    {:continue, action_result}
  end

  defp should_receive_point?(%__MODULE__{} = state, %SubmitAttempt{} = action) do
    %__MODULE__{lead_team: lead_team} = state
    %SubmitAttempt{team_id: team_id, attempt: attempt} = action

    lead_team.id != team_id and lead_team_code(state) == attempt
  end

  defp should_receive_strike?(%__MODULE__{} = state, %SubmitAttempt{} = action) do
    %__MODULE__{lead_team: lead_team} = state
    %SubmitAttempt{team_id: team_id, attempt: attempt} = action

    lead_team.id == team_id and lead_team_code(state) != attempt
  end

  defp lead_team_code(%__MODULE__{data: data, lead_team: lead_team}) do
    data |> Data.get_round(0) |> Round.get_code(lead_team.id)
  end

  defp check_last_submission(%__MODULE__{} = state, %SubmitAttempt{} = action, action_result) do
    %SubmitAttempt{team_id: team_id} = action

    case teams_without_submission(state) do
      teams when length(teams) >= 2 ->
        {:break, action_result}

      [] ->
        {:break, action_result}

      [^team_id] ->
        {:continue, action_result}
    end
  end

  defp check_remaining_lead_teams(%__MODULE__{} = state, %SubmitAttempt{}, action_result) do
    %__MODULE__{
      remaining_lead_teams: remaining_lead_teams
    } = state

    case remaining_lead_teams do
      [] ->
        {:continue, action_result}

      [next_lead_team | remaining_lead_teams] ->
        action_result =
          action_result
          |> ActionResult.add([
            LeadTeamPassed.with(
              lead_team: next_lead_team,
              remaining_lead_teams: remaining_lead_teams
            )
          ])

        {:break, action_result}
    end
  end

  defp check_game_end(%__MODULE__{data: data} = state, %SubmitAttempt{} = action, action_result) do
    teams_that_won = teams_that_won(state, action)
    teams_that_lost = teams_that_lost(state, action)

    remaining_teams = Data.get_remaining_teams(data) -- teams_that_lost

    winning_team_events =
      teams_that_won |> Enum.map(fn team -> TeamWon.with(team_id: team.id) end)

    losing_team_events =
      teams_that_lost |> Enum.map(fn team -> TeamLost.with(team_id: team.id) end)

    action_result =
      action_result
      |> ActionResult.add(losing_team_events)
      |> ActionResult.add(winning_team_events)

    ## DO STUFF
    action_result =
      case remaining_teams do
        [] ->
          action_result
          |> ActionResult.add([GameEnded.empty()])

        _ ->
          case winning_team_events do
            [] ->
              action_result
              |> ActionResult.add([RoundEnded.empty()])

            _ ->
              action_result
              |> ActionResult.add([GameEnded.empty()])
          end
      end

    {:break, action_result}
  end

  def teams_that_won(%__MODULE__{data: data} = state, %SubmitAttempt{} = action) do
    %Data{target_points: target_points} = data
    points_by_team_id = extrapolated_points_by_team_id(state, action)

    data
    |> Data.get_remaining_teams()
    |> Enum.filter(fn team -> points_by_team_id[team.id] >= target_points end)
  end

  def teams_that_lost(%__MODULE__{data: data} = state, %SubmitAttempt{} = action) do
    %Data{target_points: target_points} = data
    strikes_by_team_id = extrapolated_strikes_by_team_id(state, action)

    data
    |> Data.get_remaining_teams()
    |> Enum.filter(fn team -> strikes_by_team_id[team.id] >= target_points end)
  end

  def extrapolated_points_by_team_id(%__MODULE__{} = state, %SubmitAttempt{} = action) do
    %__MODULE__{data: %Data{teams: teams} = data} = state
    %SubmitAttempt{team_id: team_id} = action

    teams
    |> Enum.map(fn team ->
      points = data |> Data.get_points(team)

      case team.id == team_id and should_receive_point?(state, action) do
        true ->
          points + 1

        false ->
          points
      end
    end)
  end

  def extrapolated_strikes_by_team_id(%__MODULE__{} = state, %SubmitAttempt{} = action) do
    %__MODULE__{data: %Data{teams: teams} = data} = state
    %SubmitAttempt{team_id: team_id} = action

    teams
    |> Enum.map(fn team ->
      strikes = data |> Data.get_strikes(team)

      case team.id == team_id and should_receive_point?(state, action) do
        true ->
          strikes + 1

        false ->
          strikes
      end
    end)
  end

  defp teams_without_submission(%__MODULE__{data: data, lead_team: lead_team}) do
    current_round = data |> Data.get_round(0)

    data.teams
    |> Enum.filter(&(current_round |> Round.get_attempt(&1.id, lead_team.id) == nil))
    |> Enum.map(fn team -> team.id end)
  end

  def apply_event(%__MODULE__{} = state, %AttemptSubmitted{} = event) do
    %__MODULE__{
      data: data
    } = state

    %AttemptSubmitted{
      decipherer_team_id: decipherer_team_id,
      encipherer_team_id: encipherer_team_id,
      attempt: attempt
    } = event

    data =
      data
      |> Data.update_round(
        0,
        &Round.set_attempt(&1, decipherer_team_id, encipherer_team_id, attempt)
      )

    state |> where(data: data)
  end
end
