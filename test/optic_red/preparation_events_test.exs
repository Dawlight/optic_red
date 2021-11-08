defmodule OpticRed.PreparationEventsTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias OpticRed.Game.Model.{
    Data,
    Team,
    Player
  }

  alias OpticRed.Game.State

  alias OpticRed.Game.State.Preparation
  alias OpticRed.Game.State.Encipher

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

  test "Preparation -> WordsGenerated" do
    words = ["one", "two", "three", "four"]

    state =
      Preparation.where(data: Data.empty() |> Data.add_team(%Team{id: "red"}))
      |> State.apply_event(WordsGenerated.with(team_id: "red", words: words))

    assert %Preparation{data: %Data{words_by_team_id: %{"red" => ^words}}} = state
  end

  test "Preparation -> PlayerReadied" do
    state =
      Preparation.where(
        data:
          Data.empty()
          |> Data.add_player(%Player{id: "bob"})
          |> Data.add_player(%Player{id: "mel"})
      )
      |> State.apply_event(PlayerReadied.with(player_id: "bob"))

    assert %Preparation{ready_players: ready_players} = state
    assert ready_players |> MapSet.member?(%Player{id: "bob"})
  end

  test "Preparation -> NewRoundStarted" do
    data =
      Data.empty()
      |> Data.add_player(%Player{id: "bob", team_id: "red"})
      |> Data.add_player(%Player{id: "mia", team_id: "blue"})
      |> Data.add_team(%Team{id: "red"})
      |> Data.add_team(%Team{id: "blue"})

    state =
      Preparation.where(data: data)
      |> State.apply_event(NewRoundStarted.empty())

    assert %Encipher{data: %Data{teams: [%Team{id: "blue"}, %Team{id: "red"}]}} = state
  end
end
