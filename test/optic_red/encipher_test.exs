defmodule OpticRed.EncipherTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias OpticRed.Game.State

  alias OpticRed.Game.Model.{
    Data,
    Team,
    Round
  }

  alias OpticRed.Game.State.{
    Encipher
  }

  alias OpticRed.Game.Event.{
    CluesSubmitted,
    AllCluesSubmitted
  }

  alias OpticRed.Game.Action.{
    SubmitClues
  }

  test "Encipher -> SubmitClues -> [CluesSubmitted]" do
    state =
      Encipher.where(
        data:
          Data.empty()
          |> Data.add_round(Round.empty())
          |> Data.add_team(%Team{id: "red"})
          |> Data.add_team(%Team{id: "blue"})
      )

    clues = ["one", "two", "three", "four"]

    action_result =
      state
      |> State.handle_action(SubmitClues.with(team_id: "red", clues: clues))

    assert [%CluesSubmitted{team_id: "red", clues: ^clues}] = action_result.events
  end

  test "Encipher -> SubmitClues -> [CluesSubmitted, AllCluesSubmitted]" do
    state =
      Encipher.where(
        data:
          Data.empty()
          |> Data.add_round(
            Round.empty()
            |> Round.set_clues("blue", ["five", "six", "seven", "eight"])
          )
          |> Data.add_team(%Team{id: "red"})
          |> Data.add_team(%Team{id: "blue"})
      )

    clues = ["one", "two", "three", "four"]

    action_result =
      state
      |> State.handle_action(SubmitClues.with(team_id: "red", clues: clues))

    assert [%CluesSubmitted{team_id: "red", clues: ^clues}, %AllCluesSubmitted{}] =
             action_result.events
  end

  test "Encipher -> SubmitClues (already submitted) -> []" do
    state =
      Encipher.where(
        data:
          Data.empty()
          |> Data.add_round(
            Round.empty()
            |> Round.set_clues("blue", ["five", "six", "seven", "eight"])
          )
          |> Data.add_team(%Team{id: "red"})
          |> Data.add_team(%Team{id: "blue"})
      )

    clues = ["one", "two", "three", "four"]

    action_result =
      state
      |> State.handle_action(SubmitClues.with(team_id: "blue", clues: clues))

    assert [] = action_result.events
  end
end
