defmodule OpticRed.SetupEventsTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias OpticRed.Game.Model.{
    Data,
    Team,
    Player
  }

  alias OpticRed.Game.State

  alias OpticRed.Game.State.Rules.Setup
  alias OpticRed.Game.State.Rules.Preparation

  alias OpticRed.Game.Action.{
    AddTeam,
    RemoveTeam,
    AddPlayer,
    RemovePlayer,
    AssignPlayer,
    SetTargetPoints,
    StartGame
  }

  alias OpticRed.Game.Event.{
    TeamAdded,
    TeamRemoved,
    PlayerAdded,
    PlayerRemoved,
    PlayerAssignedTeam,
    TargetPointsSet,
    GameStarted
  }

  test "Setup -> TeamAdded" do
    state =
      Setup.empty()
      |> State.apply_event(TeamAdded.with(id: "red", name: "Red"))

    assert %Setup{data: %Data{teams: [%Team{id: "red", name: "Red"}]}} = state
  end

  test "Setup -> TeamRemoved" do
    state =
      Setup.where(data: Data.where(teams: [%Team{id: "red", name: "Red"}]))
      |> State.apply_event(TeamRemoved.with(id: "red"))

    assert %Setup{data: %Data{teams: []}} = state
  end

  test "Setup -> PlayerAdded" do
    state =
      Setup.empty()
      |> State.apply_event(PlayerAdded.with(id: "bob", name: "Bob"))

    assert %Setup{data: %Data{players: [%Player{id: "bob", name: "Bob"}]}} = state
  end

  test "Setup -> PlayerRemoved" do
    state =
      Setup.where(data: Data.where(teams: [%Player{id: "bob", name: "Bob"}]))
      |> State.apply_event(PlayerRemoved.with(id: "bob"))

    assert %Setup{data: %Data{players: []}} = state
  end

  test "Setup -> PlayerAssignedTeam" do
    player = %Player{id: "bob", name: "Bob"}
    team = %Team{id: "red", name: "Red"}

    state =
      Setup.where(
        data:
          Data.empty()
          |> Data.add_player(player)
          |> Data.add_team(team)
      )
      |> State.apply_event(PlayerAssignedTeam.with(player_id: "bob", team_id: "red"))

    assert %Setup{
             data: %Data{
               players: [%Player{id: "bob", name: "Bob", team_id: "red"}],
               teams: [^team]
             }
           } = state
  end

  test "Setup -> TargetPointsSet" do
    state =
      Setup.where(data: Data.empty())
      |> State.apply_event(TargetPointsSet.with(points: 1337))

    assert %Setup{data: %Data{target_points: 1337}} = state
  end

  test "Setup -> GameStarted" do
    data = Data.empty()

    state =
      Setup.where(data: data)
      |> State.apply_event(GameStarted.with(data: data))

    assert %Preparation{data: ^data} = state
  end
end
