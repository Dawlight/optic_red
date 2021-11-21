defmodule OpticRed.Game.State.Rules.Setup do
  alias OpticRed.Game.Model.Data
  defstruct data: %Data{}, closed_team_ids: MapSet.new()

  use OpticRed.Game.State

  alias OpticRed.Game.Model.{Team, Player, Data}

  alias OpticRed.Game.State.Rules.Preparation

  alias OpticRed.Game.ActionResult

  alias OpticRed.Game.Event.{
    TeamAdded,
    TeamRemoved,
    PlayerAdded,
    PlayerRemoved,
    PlayerAssignedTeam,
    TargetPointsSet,
    GameStarted,
    TeamOpened,
    TeamClosed
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

  def new() do
    where(data: Data.empty())
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

  def handle_action(%__MODULE__{} = state, %AssignPlayer{} = action) do
    %AssignPlayer{player_id: player_id, team_id: team_id} = action

    case get_team_state(state, team_id) do
      :open ->
        ActionResult.new([
          PlayerAssignedTeam.with(player_id: player_id, team_id: team_id)
        ])
        |> ActionResult.add(get_team_events(state, action))

      :closed ->
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

  def get_team_state(%__MODULE__{} = state, team_id) do
    %__MODULE__{closed_team_ids: closed_team_ids} = state

    case closed_team_ids |> MapSet.member?(team_id) do
      true -> :closed
      false -> :open
    end
  end

  defp get_team_events(
         %__MODULE__{data: data, closed_team_ids: closed_team_ids},
         %AssignPlayer{} = action
       ) do
    %Data{players: players} = data

    %AssignPlayer{
      player_id: player_id,
      team_id: team_id
    } = action

    players_after_join = players |> set_player_team(player_id, team_id)
    %{min: min, max: max} = get_team_count_extremities(players_after_join)

    max_teams = MapSet.new(max.teams)
    min_teams = MapSet.new(min.teams)

    team_closed_events =
      max_teams
      |> MapSet.difference(closed_team_ids)
      |> MapSet.to_list()
      |> Enum.map(fn team_id -> TeamClosed.with(team_id: team_id) end)

    team_opened_events =
      min_teams
      |> MapSet.intersection(closed_team_ids)
      |> MapSet.to_list()
      |> Enum.map(fn team_id -> TeamOpened.with(team_id: team_id) end)

    ActionResult.new(team_closed_events)
    |> ActionResult.add(team_opened_events)
  end

  defp get_team_count_extremities(players) do
    player_count_by_team_id =
      players
      |> Enum.filter(fn player -> player.team_id != nil end)
      |> Enum.group_by(fn player -> player.team_id end)
      |> Enum.map(fn {team_id, players} -> {team_id, length(players)} end)
      |> Map.new()

    {_, max_count} =
      player_count_by_team_id
      |> Enum.max_by(fn {_, count} -> count end, fn -> {nil, 0} end)

    {_, min_count} =
      player_count_by_team_id
      |> Enum.min_by(fn {_, count} -> count end, fn -> {nil, 0} end)

    min_teams =
      player_count_by_team_id
      |> Enum.filter(fn {_, count} -> count == min_count end)
      |> Enum.map(fn {team_id, _} -> team_id end)

    max_teams =
      player_count_by_team_id
      |> Enum.filter(fn {_, count} -> count == max_count end)
      |> Enum.map(fn {team_id, _} -> team_id end)

    %{min: %{count: min_count, teams: min_teams}, max: %{count: max_count, teams: max_teams}}
  end

  defp set_player_team(players, player_id, team_id) do
    players
    |> Enum.map(fn player ->
      case player.id do
        ^player_id -> player |> Player.where(team_id: team_id)
        _ -> player
      end
    end)
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
