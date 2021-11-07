defmodule OpticRed.DecipherTest do
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
    state =
      Decipher.where(
        data:
          Data.empty()
          |> Data.add_team(%Team{id: "red"})
          |> Data.add_team(%Team{id: "blue"})
          |> Data.add_round(
            Round.empty()
            |> Round.with_default_attempts([
              %Team{id: "red"},
              %Team{id: "blue"}
            ])
            |> Round.set_code("red", [1, 2, 3])
          ),
        lead_team: %Team{id: "red"}
      )

    attempt = [1, 2, 3]

    action_result =
      state
      |> State.handle_action(SubmitAttempt.with(team_id: "red", attempt: attempt))

    assert [
             %AttemptSubmitted{
               decipherer_team_id: "red",
               encipherer_team_id: "red",
               attempt: ^attempt
             }
           ] = action_result.events
  end

  test "Decipher -> SubmittAttempt (fail other) -> [AttemptSubmitted]" do
    state =
      Decipher.where(
        data:
          Data.empty()
          |> Data.add_team(%Team{id: "red"})
          |> Data.add_team(%Team{id: "blue"})
          |> Data.add_round(
            Round.empty()
            |> Round.with_default_attempts([
              %Team{id: "red"},
              %Team{id: "blue"}
            ])
            |> Round.set_code("blue", [1, 2, 3])
          ),
        lead_team: %Team{id: "blue"}
      )

    attempt = [3, 3, 3]

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

  test "Decipher -> SubmittAttempt (success other) -> [AttemptSubmitted, PointsIncremented]" do
    state =
      Decipher.where(
        data:
          Data.empty()
          |> Data.add_team(%Team{id: "red"})
          |> Data.add_team(%Team{id: "blue"})
          |> Data.add_round(
            Round.empty()
            |> Round.with_default_attempts([
              %Team{id: "red"},
              %Team{id: "blue"}
            ])
            |> Round.set_code("blue", [1, 2, 3])
          ),
        lead_team: %Team{id: "blue"}
      )

    attempt = [1, 2, 3]

    action_result =
      state
      |> State.handle_action(SubmitAttempt.with(team_id: "red", attempt: attempt))

    assert [
             %AttemptSubmitted{
               decipherer_team_id: "red",
               encipherer_team_id: "blue",
               attempt: ^attempt
             },
             %PointsIncremented{
               team_id: "red"
             }
           ] = action_result.events
  end

  test "Decipher -> SubmittAttempt (fail self) -> [AttemptSubmitted, StrikesIncremented]" do
    state =
      Decipher.where(
        data:
          Data.empty()
          |> Data.add_team(%Team{id: "red"})
          |> Data.add_team(%Team{id: "blue"})
          |> Data.add_round(
            Round.empty()
            |> Round.with_default_attempts([
              %Team{id: "red"},
              %Team{id: "blue"}
            ])
            |> Round.set_code("red", [1, 2, 3])
          ),
        lead_team: %Team{id: "red"}
      )

    attempt = [1, 3, 3, 7]

    action_result =
      state
      |> State.handle_action(SubmitAttempt.with(team_id: "red", attempt: attempt))

    assert [
             %AttemptSubmitted{
               decipherer_team_id: "red",
               encipherer_team_id: "red",
               attempt: ^attempt
             },
             %StrikesIncremented{
               team_id: "red"
             }
           ] = action_result.events
  end

  test "Decipher -> SubmittAttempt (all teams submitted) -> [AttemptSubmitted, LeadTeamPassed]" do
    state =
      Decipher.where(
        data:
          Data.empty()
          |> Data.add_team(%Team{id: "red"})
          |> Data.add_team(%Team{id: "blue"})
          |> Data.add_round(
            Round.empty()
            |> Round.with_default_attempts([
              %Team{id: "red"},
              %Team{id: "blue"}
            ])
            |> Round.set_code("red", [1, 2, 3])
            |> Round.set_attempt("blue", "red", [1, 2, 3])
          ),
        remaining_lead_teams: [%Team{id: "blue"}],
        lead_team: %Team{id: "red"}
      )

    attempt = [1, 2, 3]

    action_result =
      state
      |> State.handle_action(SubmitAttempt.with(team_id: "red", attempt: attempt))

    assert [
             %AttemptSubmitted{
               decipherer_team_id: "red",
               encipherer_team_id: "red",
               attempt: ^attempt
             },
             %LeadTeamPassed{
               lead_team: %Team{id: "blue"},
               remaining_lead_teams: []
             }
           ] = action_result.events
  end

  test "Decipher -> SubmittAttempt (all teams have been lead) -> [AttemptSubmitted, RoundEnded]" do
    state =
      Decipher.where(
        data:
          Data.empty()
          |> Data.set_target_points(5)
          |> Data.add_team(%Team{id: "red"})
          |> Data.add_team(%Team{id: "blue"})
          |> Data.set_team_points(%Team{id: "red"}, 0)
          |> Data.set_team_points(%Team{id: "blue"}, 0)
          |> Data.set_team_strikes(%Team{id: "red"}, 0)
          |> Data.set_team_strikes(%Team{id: "blue"}, 0)
          |> Data.add_round(
            Round.empty()
            |> Round.with_default_attempts([
              %Team{id: "red"},
              %Team{id: "blue"}
            ])
            |> Round.set_code("red", [1, 2, 3])
            |> Round.set_attempt("blue", "red", [1, 2, 3])
          ),
        remaining_lead_teams: [],
        lead_team: %Team{id: "red"}
      )

    attempt = [1, 2, 3]

    action_result =
      state
      |> State.handle_action(SubmitAttempt.with(team_id: "red", attempt: attempt))

    assert [
             %AttemptSubmitted{
               decipherer_team_id: "red",
               encipherer_team_id: "red",
               attempt: ^attempt
             },
             %RoundEnded{}
           ] = action_result.events
  end

  test "Decipher -> SubmittAttempt (all teams have been lead) -> [AttemptSubmitted, GameEnded]" do
    state =
      Decipher.where(
        data:
          Data.empty()
          |> Data.set_target_points(1)
          |> Data.add_team(%Team{id: "red"})
          |> Data.add_team(%Team{id: "blue"})
          |> Data.set_team_points(%Team{id: "red"}, 0)
          |> Data.set_team_points(%Team{id: "blue"}, 0)
          |> Data.set_team_strikes(%Team{id: "red"}, 0)
          |> Data.set_team_strikes(%Team{id: "blue"}, 0)
          |> Data.add_round(
            Round.empty()
            |> Round.with_default_attempts([
              %Team{id: "red"},
              %Team{id: "blue"}
            ])
            |> Round.set_code("red", [1, 2, 3])
            |> Round.set_attempt("red", "red", [1, 2, 3])
          ),
        remaining_lead_teams: [],
        lead_team: %Team{id: "red"}
      )

    attempt = [1, 2, 3]

    action_result =
      state
      |> State.handle_action(SubmitAttempt.with(team_id: "blue", attempt: attempt))

    assert [
             %AttemptSubmitted{
               decipherer_team_id: "blue",
               encipherer_team_id: "red",
               attempt: ^attempt
             },
             %PointsIncremented{team_id: "blue"},
             %TeamLost{team_id: "red"},
             %TeamWon{team_id: "blue"},
             %GameEnded{}
           ] = action_result.events
  end

  test "Decipher -> SubmittAttempt (win by default) -> [AttemptSubmitted, GameEnded]" do
    state =
      Decipher.where(
        data:
          Data.empty()
          |> Data.set_target_points(1)
          |> Data.add_team(%Team{id: "red"})
          |> Data.add_team(%Team{id: "blue"})
          |> Data.set_team_points(%Team{id: "red"}, 0)
          |> Data.set_team_points(%Team{id: "blue"}, 0)
          |> Data.set_team_strikes(%Team{id: "red"}, 0)
          |> Data.set_team_strikes(%Team{id: "blue"}, 0)
          |> Data.add_round(
            Round.empty()
            |> Round.with_default_attempts([
              %Team{id: "red"},
              %Team{id: "blue"}
            ])
            |> Round.set_code("red", [1, 2, 3])
            |> Round.set_attempt("blue", "red", [1, 2, 3])
          ),
        remaining_lead_teams: [],
        lead_team: %Team{id: "red"}
      )

    attempt = [3, 9, 1]

    action_result =
      state
      |> State.handle_action(SubmitAttempt.with(team_id: "red", attempt: attempt))

    assert [
             %AttemptSubmitted{
               decipherer_team_id: "red",
               encipherer_team_id: "red",
               attempt: ^attempt
             },
             %StrikesIncremented{team_id: "red"},
             %TeamLost{team_id: "red"},
             %TeamWon{team_id: "blue"},
             %GameEnded{}
           ] = action_result.events
  end
end
