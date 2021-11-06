defmodule OpticRed.DecipherTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias OpticRed.Game.Model.{
    Data,
    Team,
    Player
  }

  alias OpticRed.Game.State

  alias OpticRed.Game.State.Decipher

  alias OpticRed.Game.Action.{
    SubmitAttempt
  }

  alias OpticRed.Game.Event.{
    AttemptSubmitted
  }

  test "Decipher -> SubmittAttempt -> [AttemptSubmitted]" do
    state =
      Decipher.where(
        data:
          Data.empty()
          |> Data.add_team(%Team{id: "red"})
      )

    attempt = ["one", "two", "three", "four"]

    action_result =
      state
      |> State.handle_action(SubmitAttempt.with(team_id: "red", attempt: attempt))

    assert [
             %AttemptSubmitted{
               decipherer_team_id: "red",
               encipherer_team_id: "blue",
               attempt: ^attempt
             }
           ] = action_result.events
  end
end
