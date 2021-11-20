defmodule OpticRed.EncipherEventsTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias OpticRed.Game.State

  alias OpticRed.Game.Model.{
    Data,
    Team,
    Round
  }

  alias OpticRed.Game.State.Rules.{
    Encipher,
    Decipher
  }

  alias OpticRed.Game.Event.{
    CluesSubmitted,
    AllCluesSubmitted
  }

  alias OpticRed.Game.Action.{
    SubmitClues
  }

  test "Encipher -> CluesSubmitted" do
    clues = ["one", "two", "three"]

    teams = [%Team{id: "red"}, %Team{id: "blue"}]

    state =
      Encipher.where(
        data:
          Data.empty()
          |> Data.add_round(
            Round.empty()
            |> Round.with_default_attempts(teams)
            |> Round.with_default_clues(teams)
          )
      )
      |> State.apply_event(CluesSubmitted.with(team_id: "red", clues: clues))

    assert %Encipher{data: data} = state
    assert ^clues = data |> Data.get_round(0) |> Round.get_clues("red")
  end

  test "Encipher -> AllCluesSubmitted" do
    data =
      Data.empty()
      |> Data.add_team(%Team{id: "red"})
      |> Data.add_team(%Team{id: "blue"})

    state =
      Encipher.where(data: data)
      |> State.apply_event(AllCluesSubmitted.empty())

    assert %Decipher{data: ^data} = state

    assert %Decipher{lead_team: %Team{id: "red"}, remaining_lead_teams: [%Team{id: "blue"}]}
  end
end
