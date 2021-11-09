defmodule OpticRed.Game.State.Setup do
  alias OpticRed.Game.Model.Data
  defstruct data: %Data{}

  use OpticRed.Game.State

  alias OpticRed.Game.Model.{Team, Player, Data}

  alias OpticRed.Game.State.Preparation

  alias OpticRed.Game.ActionResult

  alias OpticRed.Game.Event.{
    TeamAdded,
    TeamRemoved,
    PlayerAdded,
    PlayerRemoved,
    PlayerAssignedTeam,
    TargetPointsSet,
    GameStarted
  }

  alias OpticRed.Game.Action.{
    AddTeam,
    RemoveTeam,
    AddPlayer,
    RemovePlayer,
    AssignPlayer,
    SetTargetPoints,
    StartGame
  }

  def new(%__MODULE__{} = state, data) do
    state |> where(data: data)
  end

  #
  # Action Handlers
  #

  def handle_action(%__MODULE__{data: data}, %AddTeam{id: id, name: name}) do
    case data |> Data.get_team_by_id(id) do
      nil ->
        ActionResult.new([TeamAdded.with(id: id, name: name)])

      _ ->
        ActionResult.empty()
    end
  end

  def handle_action(%__MODULE__{data: data}, %RemoveTeam{id: id}) do
    case data |> Data.get_team_by_id(id) do
      nil ->
        ActionResult.empty()

      _ ->
        ActionResult.new([TeamRemoved.with(id: id)])
    end
  end

  def handle_action(%__MODULE__{data: data}, %AddPlayer{id: id, name: name}) do
    case data |> Data.get_player_by_id(id) do
      nil ->
        ActionResult.new([PlayerAdded.with(id: id, name: name)])

      _ ->
        ActionResult.empty()
    end
  end

  def handle_action(%__MODULE__{data: data}, %RemovePlayer{id: id}) do
    case data |> Data.get_player_by_id(id) do
      nil ->
        ActionResult.empty()

      _ ->
        ActionResult.new([PlayerRemoved.with(id: id)])
    end
  end

  def handle_action(%__MODULE__{data: data}, %AssignPlayer{player_id: player_id, team_id: team_id}) do
    player = data |> Data.get_player_by_id(player_id)
    team = data |> Data.get_team_by_id(team_id)

    case {player, team, team_id} do
      {%Player{} = player, %Team{} = team, _} ->
        check_player_already_assigned(player, team.id)

      {%Player{} = player, _, nil} ->
        check_player_already_assigned(player, team_id)

      _ ->
        ActionResult.empty()
    end
  end

  def handle_action(%__MODULE__{}, %SetTargetPoints{points: points}) do
    ActionResult.new([TargetPointsSet.with(points: points)])
  end

  def handle_action(%__MODULE__{data: data} = state, %StartGame{}) do
    %Data{teams: teams} = data

    case length(teams) >= 2 do
      true ->
        check_player_distribution(state)

      false ->
        ActionResult.empty()
    end
  end

  def handle_action(%__MODULE__{}, _) do
    # TODO: Handle errors?
    ActionResult.empty()
  end

  #
  # Event Application
  #

  def apply_event(%__MODULE__{data: data} = state, %TeamAdded{id: id, name: name}) do
    state |> where(data: data |> Data.add_team(%Team{id: id, name: name}))
  end

  def apply_event(%__MODULE__{data: data} = state, %TeamRemoved{id: id}) do
    state |> where(data: data |> Data.remove_team_by_id(id))
  end

  def apply_event(%__MODULE__{data: data} = state, %PlayerAdded{id: id, name: name}) do
    state |> where(data: data |> Data.add_player(%Player{id: id, name: name}))
  end

  def apply_event(%__MODULE__{data: data} = state, %PlayerRemoved{id: id}) do
    state |> where(data: data |> Data.remove_player_by_id(id))
  end

  def apply_event(%__MODULE__{data: data} = state, %PlayerAssignedTeam{} = event) do
    %PlayerAssignedTeam{player_id: player_id, team_id: team_id} = event

    player = data |> Data.get_player_by_id(player_id)
    team = data |> Data.get_team_by_id(team_id)

    state |> where(data: data |> Data.set_player_team(player, team))
  end

  def apply_event(%__MODULE__{data: data} = state, %TargetPointsSet{points: points}) do
    state |> where(data: data |> Data.set_target_points(points))
  end

  def apply_event(%__MODULE__{data: data}, %GameStarted{}) do
    Preparation.where(data: data)
  end

  def apply_event(%__MODULE__{} = state, _event) do
    state
  end

  #
  # Private
  #

  defp check_player_already_assigned(%Player{id: player_id, team_id: assigned_team_id}, team_id) do
    case assigned_team_id == team_id do
      true ->
        ActionResult.empty()

      false ->
        ActionResult.new([
          PlayerAssignedTeam.with(player_id: player_id, team_id: team_id)
        ])
    end
  end

  defp check_player_distribution(%__MODULE__{data: data}) do
    %Data{teams: teams, players: players} = data

    min_team_player_count = div(length(players), length(teams))

    count_by_team_id =
      players
      |> Enum.group_by(fn player -> player.team_id end)
      |> Enum.map(fn {team_id, players} -> {team_id, length(players)} end)
      |> Map.new()

    case count_by_team_id do
      # Some players unassigned
      %{nil: _} ->
        ActionResult.empty()

      _ ->
        fairly_distributed_players? =
          count_by_team_id |> Enum.all?(fn {_, count} -> count >= min_team_player_count end)

        case fairly_distributed_players? do
          true ->
            ActionResult.new([GameStarted.empty()])

          false ->
            ActionResult.empty()
        end
    end
  end
end
