defmodule OpticRed.SetupActionsTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias OpticRed.Game.Model.{
    Data,
    Team,
    Player
  }

  alias OpticRed.Game.State

  alias OpticRed.Game.State.Setup

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

  test "Setup -> AddTeam -> [TeamAdded]" do
    state = Setup.where(data: Data.empty())

    action_result =
      state
      |> State.handle_action(AddTeam.with(id: "red", name: "Red Team"))

    assert [%TeamAdded{id: "red"}] = action_result.events
  end

  test "Setup -> AddTeam (already existing) -> []" do
    state =
      Setup.where(data: Data.empty() |> Data.add_team(Team.where(id: "red", name: "Red Team")))

    action_result =
      state
      |> State.handle_action(AddTeam.with(id: "red", name: "Red Team"))

    assert [] = action_result.events
  end

  test "Setup -> RemoveTeam -> [TeamRemoved]" do
    state =
      Setup.where(data: Data.empty() |> Data.add_team(Team.where(id: "red", name: "Red Team")))

    action_result =
      state
      |> State.handle_action(RemoveTeam.with(id: "red"))

    assert [%TeamRemoved{id: "red"}] = action_result.events
  end

  test "Setup -> RemoveTeam (doesn't exist) -> []" do
    state = Setup.where(data: Data.empty())

    action_result =
      state
      |> State.handle_action(RemoveTeam.with(id: "red"))

    assert [] = action_result.events
  end

  test "Setup -> AddPlayer -> [PlayerAdded]" do
    state = Setup.where(data: Data.empty())

    action_result =
      state
      |> State.handle_action(AddPlayer.with(id: "bob", name: "Bob"))

    assert [%PlayerAdded{id: "bob"}] = action_result.events
  end

  test "Setup -> AddPlayer (already existing) -> []" do
    state =
      Setup.where(data: Data.empty() |> Data.add_player(Player.where(id: "bob", name: "Bob")))

    action_result =
      state
      |> State.handle_action(AddPlayer.with(id: "bob", name: "Bob"))

    assert [] = action_result.events
  end

  test "Setup -> RemovePlayer -> [PlayerRemoved]" do
    state =
      Setup.where(data: Data.empty() |> Data.add_player(Player.where(id: "bob", name: "Bob")))

    action_result =
      state
      |> State.handle_action(RemovePlayer.with(id: "bob"))

    assert [%PlayerRemoved{id: "bob"}] = action_result.events
  end

  test "Setup -> RemovePlayer (doesn't exist) -> []" do
    state = Setup.where(data: Data.empty())

    action_result =
      state
      |> State.handle_action(RemovePlayer.with(id: "bob"))

    assert [] = action_result.events
  end

  test "Setup -> AssignPlayer -> [PlayerAssignedTeam]" do
    state =
      Setup.where(
        data:
          Data.empty()
          |> Data.add_player(Player.where(id: "bob"))
          |> Data.add_team(Team.where(id: "red"))
      )

    action_result =
      state
      |> State.handle_action(AssignPlayer.with(player_id: "bob", team_id: "red"))

    assert [%PlayerAssignedTeam{player_id: "bob", team_id: "red"}] = action_result.events
  end

  test "Setup -> AssignPlayer (player doesn't exist) -> [PlayerAssignedTeam]" do
    state =
      Setup.where(
        data:
          Data.empty()
          |> Data.add_team(Team.where(id: "red"))
      )

    action_result =
      state
      |> State.handle_action(AssignPlayer.with(player_id: "bob", team_id: "red"))

    assert [] = action_result.events
  end

  test "Setup -> AssignPlayer (team doesn't exist) -> [PlayerAssignedTeam]" do
    state =
      Setup.where(
        data:
          Data.empty()
          |> Data.add_player(Player.where(id: "bob"))
      )

    action_result =
      state
      |> State.handle_action(AssignPlayer.with(player_id: "bob", team_id: "red"))

    assert [] = action_result.events
  end

  test "Setup -> AssignPlayer (double assign) -> [PlayerAssignedTeam]" do
    state =
      Setup.where(
        data:
          Data.empty()
          |> Data.add_player(Player.where(id: "bob", team_id: "red"))
          |> Data.add_team(Team.where(id: "red"))
      )

    action_result =
      state
      |> State.handle_action(AssignPlayer.with(player_id: "bob", team_id: "red"))

    assert [] = action_result.events
  end

  test "Setup -> AssignPlayer (unassign) -> [PlayerAssignedTeam]" do
    state =
      Setup.where(
        data:
          Data.empty()
          |> Data.add_player(Player.where(id: "bob", team_id: "red"))
          |> Data.add_team(Team.where(id: "red"))
      )

    action_result =
      state
      |> State.handle_action(AssignPlayer.with(player_id: "bob", team_id: nil))

    assert [%PlayerAssignedTeam{player_id: "bob", team_id: nil}] = action_result.events
  end

  test "Setup -> SetTargetPoints -> TargetPointsSet" do
    state = Setup.where(data: Data.empty())

    action_result =
      state
      |> State.handle_action(SetTargetPoints.with(points: 1337))

    assert [%TargetPointsSet{points: 1337}] = action_result.events
  end

  test "Setup -> StartGame -> [GameStarted]" do
    state =
      Setup.where(
        data:
          Data.empty()
          |> Data.add_team(%Team{id: "red"})
          |> Data.add_team(%Team{id: "blue"})
          |> Data.add_player(%Player{id: "bob", team_id: "red"})
          |> Data.add_player(%Player{id: "bam", team_id: "red"})
          |> Data.add_player(%Player{id: "mel", team_id: "blue"})
          |> Data.add_player(%Player{id: "sal", team_id: "blue"})
      )

    action_result =
      state
      |> State.handle_action(StartGame.empty())

    assert [%GameStarted{}] = action_result.events
  end

  test "Setup -> StartGame (unassigned player) -> []" do
    state =
      Setup.where(
        data:
          Data.empty()
          |> Data.add_team(%Team{id: "red"})
          |> Data.add_team(%Team{id: "blue"})
          |> Data.add_player(%Player{id: "bob"})
          |> Data.add_player(%Player{id: "sal"})
      )

    action_result =
      state
      |> State.handle_action(StartGame.empty())

    assert [] = action_result.events
  end

  test "Setup -> StartGame (badly distributed players) -> []" do
    state =
      Setup.where(
        data:
          Data.empty()
          |> Data.add_team(%Team{id: "red"})
          |> Data.add_team(%Team{id: "blue"})
          |> Data.add_player(%Player{id: "bob", team_id: "red"})
          |> Data.add_player(%Player{id: "bam", team_id: "blue"})
          |> Data.add_player(%Player{id: "mel", team_id: "blue"})
          |> Data.add_player(%Player{id: "sal", team_id: "blue"})
      )

    action_result =
      state
      |> State.handle_action(StartGame.empty())

    assert [] = action_result.events
  end
end
