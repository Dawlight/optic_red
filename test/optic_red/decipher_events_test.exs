defmodule OpticRed.DecipherActionsTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias OpticRed.Game.Model.{
    Data,
    Round,
    Team,
    Player
  }

  alias OpticRed.Game.State

  alias OpticRed.Game.State.Decipher

  alias OpticRed.Game.Action.{
    SubmitAttempt
  }

  alias OpticRed.Game.Event.{
    AttemptSubmitted,
    PointsIncremented,
    StrikesIncremented,
    LeadTeamPassed,
    TeamWon,
    TeamLost,
    RoundEnded,
    GameEnded
  }

  test "Decipher -> SubmittAttempt (success self) -> [AttemptSubmitted]" do
  end
end
