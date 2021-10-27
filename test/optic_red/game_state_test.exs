defmodule OpticRed.GameSateTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias OpticRed.Game.State

  alias OpticRed.Game.State.{
    Data,
    Team,
    Player
  }

  alias OpticRed.Game.State.{
    Setup,
    Preparation,
    Encipher
  }

  alias OpticRed.Game.Event.{
    TeamAdded,
    PlayerAdded,
    TeamRemoved,
    PlayerRemoved,
    PlayerAssignedTeam,
    TargetScoreSet,
    GameStarted,
    WordsGenerated,
    PlayerReadied,
    NewRoundStarted
  }

  test "Setup -> TeamAdded" do
    state =
      [
        TeamAdded.with(id: "red", name: "Team Red"),
        TeamAdded.with(id: "blue", name: "Team Blue")
      ]
      |> State.build_state(Setup.empty())

    %Setup{data: %Data{teams: teams}} = state

    [
      %Team{id: "blue"},
      %Team{id: "red"}
    ] = teams
  end

  test "Setup -> TeamRemoved" do
    state =
      [
        TeamAdded.with(id: "red", name: "Team Red"),
        TeamAdded.with(id: "blue", name: "Team Blue"),
        TeamRemoved.with(id: "red")
      ]
      |> State.build_state(Setup.empty())

    %Setup{data: data} = state

    nil = data |> Data.get_team_by_id("red")
    %Team{id: "blue"} = data |> Data.get_team_by_id("blue")
  end

  test "Setup -> PlayerAdded" do
    state =
      [
        PlayerAdded.with(id: "bob", name: "Bob"),
        PlayerAdded.with(id: "sal", name: "Sal")
      ]
      |> State.build_state(Setup.empty())

    %Setup{data: %Data{players: players}} = state

    [
      %Player{id: "sal", name: "Sal"},
      %Player{id: "bob", name: "Bob"}
    ] = players
  end

  test "Setup -> PlayerRemoved" do
    state =
      [
        PlayerAdded.with(id: "bob", name: "Bob"),
        PlayerAdded.with(id: "sal", name: "Sal"),
        PlayerRemoved.with(id: "sal")
      ]
      |> State.build_state(Setup.empty())

    %Setup{data: data} = state

    nil = data |> Data.get_player_by_id("sal")
    %Player{id: bob} = data |> Data.get_player_by_id("bob")
  end

  test "Setup -> PlayerAssignedTeam" do
    # Normal assign
    state1 =
      [
        TeamAdded.with(id: "blue", name: "Team Blue"),
        PlayerAdded.with(id: "bob", name: "Bob"),
        PlayerAssignedTeam.with(player_id: "bob", team_id: "blue")
      ]
      |> State.build_state(Setup.empty())

    # Assign to non-existent team
    state2 =
      [
        TeamAdded.with(id: "blue", name: "Team Blue"),
        PlayerAdded.with(id: "bob", name: "Bob"),
        PlayerAssignedTeam.with(player_id: "bob", team_id: "red")
      ]
      |> State.build_state(Setup.empty())

    # Assign and unassign to team
    state3 =
      [
        TeamAdded.with(id: "blue", name: "Team Blue"),
        PlayerAdded.with(id: "bob", name: "Bob"),
        PlayerAssignedTeam.with(player_id: "bob", team_id: "blue"),
        PlayerAssignedTeam.with(player_id: "bob", team_id: nil)
      ]
      |> State.build_state(Setup.empty())

    %Setup{data: data} = state1
    [%Player{id: "bob"}] = data |> Data.get_players_by_team_id("blue")

    %Setup{data: data} = state2
    [] = data |> Data.get_players_by_team_id("red")

    %Setup{data: data} = state3
    [] = data |> Data.get_players_by_team_id("blue")
  end

  test "Setup -> TargetScoreSet" do
    state =
      [
        TargetScoreSet.with(score: 1337)
      ]
      |> State.build_state(Setup.empty())

    %Setup{data: %Data{target_score: 1337}} = state
  end

  test "Setup -> GameStarted -> Preparation" do
    state =
      [
        GameStarted.empty()
      ]
      |> State.build_state(Setup.empty())

    %Preparation{} = state
  end

  test "Preparation -> WordsGenerated" do
    red_words = ["rudolph", "red", "nose", "reindeer"]

    state =
      [
        TeamAdded.with(id: "red"),
        PlayerAdded.with(id: "bob"),
        PlayerAssignedTeam.with(player_id: "bob", team_id: "red"),
        GameStarted.empty(),
        WordsGenerated.with(team_id: "red", words: ["rudolph", "red", "nose", "reindeer"])
      ]
      |> State.build_state(Setup.empty())

    %Preparation{data: %Data{words_by_team_id: words_by_team_id}} = state
    %{"red" => ^red_words} = words_by_team_id
  end

  test "Preparation -> PlayerReadied (adds readied player)" do
    state =
      [
        TeamAdded.with(id: "red"),
        PlayerAdded.with(id: "bob"),
        PlayerAdded.with(id: "sal"),
        PlayerAssignedTeam.with(player_id: "bob", team_id: "red"),
        PlayerAssignedTeam.with(player_id: "sal", team_id: "red"),
        GameStarted.empty(),
        PlayerReadied.with(player_id: "bob", ready?: true)
      ]
      |> State.build_state(Setup.empty())

    %Preparation{ready_players: [%Player{id: "bob"}]} = state
  end

  test "Preparation -> NewRoundStarted -> Encipher" do
    state =
      [
        TeamAdded.with(id: "red"),
        PlayerAdded.with(id: "bob"),
        PlayerAssignedTeam.with(player_id: "bob", team_id: "red"),
        GameStarted.empty(),
        PlayerReadied.with(player_id: "bob", ready?: true),
        NewRoundStarted.empty()
      ]
      |> State.build_state(Setup.empty())

    %Encipher{} = state
  end
end
