defmodule OpticRed.DecipherEventsTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias OpticRed.Game.Model.{
    Data,
    Round,
    Team,
    Player
  }

  alias OpticRed.Game.State

  alias OpticRed.Game.State.Rules.{
    Decipher,
    RoundEnd,
    GameEnd
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

  test "Decipher -> AttemptSubmitted" do
    teams = [team1, team2] = [%Team{id: "red"}, %Team{id: "blue"}]

    [player1, player2] = [
      %Player{id: "bob", team_id: "red"},
      %Player{id: "mel", team_id: "blue"}
    ]

    data =
      Data.empty()
      |> Data.add_team(team1)
      |> Data.add_team(team2)
      |> Data.add_player(player1)
      |> Data.add_player(player2)
      |> Data.add_round(
        Round.empty()
        |> Round.with_default_attempts(teams)
        |> Round.with_default_clues(teams)
        |> Round.with_codes(%{"red" => [1, 2, 3], "blue" => [3, 2, 1]})
        |> Round.with_encipherers(%{"red" => player1, "blue" => player2})
      )

    state =
      Decipher.where(data: data)
      |> State.apply_event(
        AttemptSubmitted.with(
          decipherer_team_id: "red",
          encipherer_team_id: "blue",
          attempt: [1, 2, 3]
        )
      )

    assert %Decipher{
             data: %Data{
               rounds: [
                 %Round{
                   attempts_by_team_id: %{
                     "red" => %{
                       "blue" => [1, 2, 3]
                     }
                   }
                 }
               ]
             }
           } = state
  end

  test "Decipher -> PointsIncremented" do
    [team1, team2] = [%Team{id: "red"}, %Team{id: "blue"}]

    data =
      Data.empty()
      |> Data.set_team_points(team1, 0)
      |> Data.set_team_points(team2, 0)

    state =
      Decipher.where(data: data)
      |> State.apply_event(PointsIncremented.with(team_id: "red"))
      |> State.apply_event(PointsIncremented.with(team_id: "red"))

    assert %Decipher{
             data: %Data{
               points_by_team_id: %{"red" => 2}
             }
           } = state
  end

  test "Decipher -> StrikesIncremented" do
    [team1, team2] = [%Team{id: "red"}, %Team{id: "blue"}]

    data =
      Data.empty()
      |> Data.set_team_strikes(team1, 0)
      |> Data.set_team_strikes(team2, 0)

    state =
      Decipher.where(data: data)
      |> State.apply_event(StrikesIncremented.with(team_id: "red"))
      |> State.apply_event(StrikesIncremented.with(team_id: "red"))

    assert %Decipher{
             data: %Data{
               strikes_by_team_id: %{"red" => 2}
             }
           } = state
  end

  test "Decipher -> LeadTeamPassed" do
    [team1, team2] = [%Team{id: "red"}, %Team{id: "blue"}]

    data = Data.empty()

    state =
      Decipher.where(data: data)
      |> State.apply_event(LeadTeamPassed.with(lead_team: team1, remaining_lead_teams: [team2]))

    assert %Decipher{
             lead_team: ^team1,
             remaining_lead_teams: [^team2]
           } = state
  end

  test "Decipher -> RoundEnded" do
    data = Data.empty()

    state =
      Decipher.where(data: data)
      |> State.apply_event(RoundEnded.empty())

    assert %RoundEnd{data: ^data} = state
  end

  test "Decipher -> GameEnded" do
    data = Data.empty()

    state =
      Decipher.where(data: data)
      |> State.apply_event(GameEnded.empty())

    assert %GameEnd{data: ^data} = state
  end

  test "Decipher -> TeamLost" do
    team1 = %Team{id: "red"}
    team2 = %Team{id: "blue"}

    data =
      Data.empty()
      |> Data.add_team(team1)
      |> Data.add_team(team2)

    state =
      Decipher.where(data: data)
      |> State.apply_event(TeamLost.with(team_id: "red"))
      |> State.apply_event(TeamLost.with(team_id: "blue"))

    assert %Decipher{losing_teams: [^team2, ^team1]} = state
  end

  test "Decipher -> TeamWon" do
    team1 = %Team{id: "red"}
    team2 = %Team{id: "blue"}

    data =
      Data.empty()
      |> Data.add_team(team1)
      |> Data.add_team(team2)

    state =
      Decipher.where(data: data)
      |> State.apply_event(TeamWon.with(team_id: "red"))
      |> State.apply_event(TeamWon.with(team_id: "blue"))

    assert %Decipher{winning_teams: [^team2, ^team1]} = state
  end
end
