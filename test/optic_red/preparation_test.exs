defmodule OpticRed.PreparationTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias OpticRed.Game.Model.{
    Data,
    Team,
    Player
  }

  alias OpticRed.Game.State

  alias OpticRed.Game.State.Preparation

  alias OpticRed.Game.Action.{
    GenerateWords,
    ReadyPlayer,
    StartNewRound
  }

  alias OpticRed.Game.Event.{
    WordsGenerated,
    PlayerReadied,
    NewRoundStarted
  }

  test "Preparation -> GenerateWords -> [WordsGenerated]" do
    state =
      Preparation.where(
        data:
          Data.empty()
          |> Data.add_team(%Team{id: "red"})
      )

    words = ["one", "two", "three", "four"]

    action_result =
      state
      |> State.handle_action(GenerateWords.with(team_id: "red", words: words))

    assert [%WordsGenerated{team_id: "red", words: ^words}] = action_result.events
  end

  test "Preparation -> GenerateWords (teams doesn't exist) -> [WordsGenerated]" do
    state =
      Preparation.where(
        data:
          Data.empty()
          |> Data.add_team(%Team{id: "blue"})
      )

    words = ["one", "two", "three", "four"]

    action_result =
      state
      |> State.handle_action(GenerateWords.with(team_id: "red", words: words))

    assert [] = action_result.events
  end

  test "Preparation -> ReadyPlayer (player not ready) -> [PlayerReadied]" do
    state =
      Preparation.where(
        data:
          Data.empty()
          |> Data.add_player(%Player{id: "bob"})
      )

    action_result =
      state
      |> State.handle_action(ReadyPlayer.with(player_id: "bob", ready?: true))

    assert [%PlayerReadied{player_id: "bob", ready?: true}] = action_result.events
  end

  test "Preparation -> ReadyPlayer (unready a non-ready player) -> []" do
    state =
      Preparation.where(
        data:
          Data.empty()
          |> Data.add_player(%Player{id: "bob"})
      )

    action_result =
      state
      |> State.handle_action(ReadyPlayer.with(player_id: "bob", ready?: false))

    assert [] = action_result.events
  end

  test "Preparation -> ReadyPlayer (ready a ready player) -> []" do
    state =
      Preparation.where(
        data:
          Data.empty()
          |> Data.add_player(%Player{id: "bob"}),
        ready_players: MapSet.new([%Player{id: "bob"}])
      )

    action_result =
      state
      |> State.handle_action(ReadyPlayer.with(player_id: "bob", ready?: true))

    assert [] = action_result.events
  end

  test "Preparation -> StartNewRound -> [NewRoundStarted]" do
    state =
      Preparation.where(
        data:
          Data.empty()
          |> Data.add_team(%Team{id: "red"})
          |> Data.add_team(%Team{id: "blue"})
          |> Data.add_player(%Player{id: "bob"})
          |> Data.set_team_words(%Team{id: "red"}, ["one"])
          |> Data.set_team_words(%Team{id: "blue"}, ["two"]),
        ready_players: MapSet.new([%Player{id: "bob"}])
      )

    action_result =
      state
      |> State.handle_action(StartNewRound.empty())

    assert [%NewRoundStarted{}] = action_result.events
  end

  test "Preparation -> StartNewRound -> []" do
    state =
      Preparation.where(
        data:
          Data.empty()
          |> Data.add_team(%Team{id: "red"})
          |> Data.add_team(%Team{id: "blue"})
          |> Data.add_player(%Player{id: "bob"})
          |> Data.set_team_words(%Team{id: "red"}, ["one"])
          |> Data.set_team_words(%Team{id: "blue"}, ["two"])
      )

    action_result =
      state
      |> State.handle_action(StartNewRound.empty())

    assert [] = action_result.events
  end

  test "Preparation -> StartNewRound (not all teams have words) -> []" do
    state =
      Preparation.where(
        data:
          Data.empty()
          |> Data.add_team(%Team{id: "red"})
          |> Data.add_team(%Team{id: "blue"})
          |> Data.add_player(%Player{id: "bob"})
      )

    action_result =
      state
      |> State.handle_action(StartNewRound.empty())

    assert [] = action_result.events
  end

  test "Preparation -> StartNewRound (no teams) -> []" do
    state =
      Preparation.where(
        data:
          Data.empty()
          |> Data.add_player(%Player{id: "bob"})
      )

    action_result =
      state
      |> State.handle_action(StartNewRound.empty())

    assert [] = action_result.events
  end
end
