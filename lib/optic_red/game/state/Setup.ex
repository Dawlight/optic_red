defmodule OpticRed.Game.State.Setup do
  alias OpticRed.Game.Model.Data
  defstruct data: %Data{}

  use OpticRed.Game.State

  alias OpticRed.Game.Model.{Team, Player}

  alias OpticRed.Game.State.Preparation

  alias OpticRed.Game.Event.{
    TeamAdded,
    TeamRemoved,
    PlayerAdded,
    PlayerRemoved,
    PlayerAssignedTeam,
    TargetScoreSet,
    GameStarted
  }

  def new(%__MODULE__{} = state, data) do
    state |> where(data: data)
  end

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

    team_exists? = data |> Data.get_team_by_id(team_id) != nil

    if team_exists? or team_id == nil do
      player = data |> Data.get_player_by_id(player_id)
      team = data |> Data.get_team_by_id(team_id)

      state |> where(data: data |> Data.set_player_team(player, team))
    else
      state
    end
  end

  def apply_event(%__MODULE__{data: data} = state, %TargetScoreSet{score: score}) do
    state |> where(data: data |> Data.set_target_score(score))
  end

  def apply_event(%__MODULE__{data: data}, %GameStarted{}) do
    Preparation.where(data: data)
  end

  def apply_event(%__MODULE__{} = state, _event) do
    state
  end
end
