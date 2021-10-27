defmodule OpticRed.Game.State.Setup do
  alias OpticRed.Game.State.Data
  defstruct data: %Data{}

  use OpticRed.Game.State

  alias OpticRed.Game.State.Team
  alias OpticRed.Game.State.Player

  alias OpticRed.Game.State.Preparation

  alias OpticRed.Game.Event.TeamAdded
  alias OpticRed.Game.Event.TeamRemoved
  alias OpticRed.Game.Event.PlayerAdded
  alias OpticRed.Game.Event.PlayerRemoved
  alias OpticRed.Game.Event.PlayerAssignedTeam
  alias OpticRed.Game.Event.TargetScoreSet
  alias OpticRed.Game.Event.GameStarted

  def apply_event(%__MODULE__{data: data} = state, %TeamAdded{id: id, name: name}) do
    state |> __MODULE__.with(data: data |> Data.add_team(%Team{id: id, name: name}))
  end

  def apply_event(%__MODULE__{data: data} = state, %TeamRemoved{id: id}) do
    state |> __MODULE__.with(data: data |> Data.remove_team_by_id(id))
  end

  def apply_event(%__MODULE__{data: data} = state, %PlayerAdded{id: id, name: name}) do
    state |> __MODULE__.with(data: data |> Data.add_player(%Player{id: id, name: name}))
  end

  def apply_event(%__MODULE__{data: data} = state, %PlayerRemoved{id: id}) do
    state |> __MODULE__.with(data: data |> Data.remove_player_by_id(id))
  end

  def apply_event(%__MODULE__{data: data} = state, %PlayerAssignedTeam{} = event) do
    %PlayerAssignedTeam{player_id: player_id, team_id: team_id} = event

    team_exists? = data |> Data.get_team_by_id(team_id) != nil

    if team_exists? or team_id == nil do
      player = data |> Data.get_player_by_id(player_id)
      team = data |> Data.get_team_by_id(team_id)

      state |> __MODULE__.with(data: data |> Data.set_player_team(player, team))
    else
      state
    end
  end

  def apply_event(%__MODULE__{data: data} = state, %TargetScoreSet{score: score}) do
    state |> __MODULE__.with(data: data |> Data.set_target_score(score))
  end

  def apply_event(%__MODULE__{data: data}, %GameStarted{}) do
    Preparation.new(data)
  end

  def apply_event(%__MODULE__{} = state, _event) do
    state
  end
end
