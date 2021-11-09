defmodule OpticRed.Game.State.Decipher do
  alias OpticRed.Game.Model.Data

  defstruct data: %Data{},
            lead_team: nil,
            remaining_lead_teams: [],
            winning_teams: [],
            losing_teams: []

  use OpticRed.Game.State

  alias OpticRed.Game.Model.{Round, Team}

  alias OpticRed.Game.ActionResult

  alias OpticRed.Game.Event.{
    AttemptSubmitted,
    PointsIncremented,
    StrikesIncremented,
    LeadTeamPassed,
    RoundEnded,
    GameEnded,
    TeamWon,
    TeamLost
  }

  alias OpticRed.Game.Action.{SubmitAttempt}

  alias OpticRed.Game.State.{
    RoundEnd,
    GameEnd
  }

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
    %__MODULE__{data: data, lead_team: lead_team} = state
    %Data{teams: teams} = data

    current_round = data |> Data.get_round(0)

    initialized_round? =
      teams |> Enum.all?(fn team -> current_round.attempts_by_team_id[team.id] != nil end)

    result = ActionResult.new([])

    case {initialized_round?, lead_team} do
      {_, nil} ->
        result

      {false, _} ->
        result

      {true, _} ->
        with {:continue, result} <- check_valid_submission(state, action, result),
             {:continue, result} <- check_scoring(state, action, result),
             {:continue, result} <- check_last_submission(state, action, result),
             {:continue, result} <- check_remaining_lead_teams(state, action, result),
             {:continue, result} <- check_game_end(state, action, result) do
          result
        else
          {:break, result} -> result
        end
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
             decipherer_team_id: team_id,
             encipherer_team_id: lead_team.id,
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
          action_result |> ActionResult.add([PointsIncremented.with(team_id: team_id)])

        should_receive_strike?(state, action) ->
          action_result |> ActionResult.add([StrikesIncremented.with(team_id: team_id)])

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
    winning_teams = winning_teams(state, action)
    losing_teams = losing_teams(state, action)
    unaffected_teams = (data.teams -- losing_teams) -- winning_teams

    losing_team_events = losing_teams |> Enum.map(fn team -> TeamLost.with(team_id: team.id) end)

    winning_team_events = winning_teams |> Enum.map(fn team -> TeamWon.with(team_id: team.id) end)

    action_result =
      cond do
        # At least one team won!
        length(winning_teams) >= 1 ->
          action_result
          |> ActionResult.add(losing_team_events)
          |> ActionResult.add(to_team_lost_events(unaffected_teams))
          |> ActionResult.add(winning_team_events)
          |> ActionResult.add([GameEnded.empty()])

        # Last man standing!
        length(unaffected_teams) == 1 ->
          action_result
          |> ActionResult.add(losing_team_events)
          |> ActionResult.add(to_team_won_events(unaffected_teams))
          |> ActionResult.add([GameEnded.empty()])

        # Everyone lost...
        winning_teams == [] and unaffected_teams == [] ->
          action_result
          |> ActionResult.add(losing_team_events)
          |> ActionResult.add([GameEnded.empty()])

        # The world moves on.
        true ->
          action_result
          |> ActionResult.add(losing_team_events)
          |> ActionResult.add(winning_team_events)
          |> ActionResult.add([RoundEnded.empty()])
      end

    ## DO STUFF
    {:break, action_result}
  end

  def to_team_lost_events(teams) do
    teams |> Enum.map(fn team -> TeamLost.with(team_id: team.id) end)
  end

  def to_team_won_events(teams) do
    teams |> Enum.map(fn team -> TeamWon.with(team_id: team.id) end)
  end

  def winning_teams(%__MODULE__{data: data} = state, %SubmitAttempt{} = action) do
    %Data{target_points: target_points} = data

    points_by_team_id = extrapolated_points_by_team_id(state, action)

    data
    |> Data.get_remaining_teams()
    |> Enum.filter(fn team -> points_by_team_id[team.id] >= target_points end)
  end

  def losing_teams(%__MODULE__{data: data} = state, %SubmitAttempt{} = action) do
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
          {team.id, points + 1}

        false ->
          {team.id, points}
      end
    end)
    |> Map.new()
  end

  def extrapolated_strikes_by_team_id(%__MODULE__{} = state, %SubmitAttempt{} = action) do
    %__MODULE__{data: %Data{teams: teams} = data} = state
    %SubmitAttempt{team_id: team_id} = action

    teams
    |> Enum.map(fn team ->
      strikes = data |> Data.get_strikes(team)

      case team.id == team_id and should_receive_strike?(state, action) do
        true ->
          {team.id, strikes + 1}

        false ->
          {team.id, strikes}
      end
    end)
    |> Map.new()
  end

  defp teams_without_submission(%__MODULE__{data: data, lead_team: lead_team}) do
    current_round = data |> Data.get_round(0)

    data.teams
    |> Enum.filter(&(current_round |> Round.get_attempt(&1.id, lead_team.id) == nil))
    |> Enum.map(fn team -> team.id end)
  end

  #
  # Event Handlers
  #

  def apply_event(%__MODULE__{data: data} = state, %AttemptSubmitted{} = event) do
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

  def apply_event(%__MODULE__{data: data} = state, %PointsIncremented{team_id: team_id}) do
    team = %Team{id: team_id}
    points = data |> Data.get_points(team)
    data = data |> Data.set_team_points(team, points + 1)

    state |> where(data: data)
  end

  def apply_event(%__MODULE__{data: data} = state, %StrikesIncremented{team_id: team_id}) do
    team = %Team{id: team_id}
    strikes = data |> Data.get_strikes(team)
    data = data |> Data.set_team_strikes(team, strikes + 1)

    state |> where(data: data)
  end

  def apply_event(%__MODULE__{data: data} = state, %LeadTeamPassed{} = event) do
    %LeadTeamPassed{
      lead_team: lead_team,
      remaining_lead_teams: remaining_lead_teams
    } = event

    state
    |> where(
      data: data,
      lead_team: lead_team,
      remaining_lead_teams: remaining_lead_teams
    )
  end

  def apply_event(%__MODULE__{data: data}, %RoundEnded{}) do
    RoundEnd.new(data)
  end

  def apply_event(%__MODULE__{data: data}, %GameEnded{}) do
    GameEnd.where(data: data)
  end

  def apply_event(%__MODULE__{} = state, %TeamLost{team_id: team_id}) do
    %__MODULE__{data: data, losing_teams: losing_teams} = state

    team = data |> Data.get_team_by_id(team_id)
    state |> where(losing_teams: [team | losing_teams])
  end

  def apply_event(%__MODULE__{} = state, %TeamWon{team_id: team_id}) do
    %__MODULE__{data: data, winning_teams: winning_teams} = state

    team = data |> Data.get_team_by_id(team_id)
    state |> where(winning_teams: [team | winning_teams])
  end
end
