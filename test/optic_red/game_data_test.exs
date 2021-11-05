defmodule OpticRed.GameSateTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias OpticRed.Game.Model.{
    Data,
    Team,
    Player,
    Round
  }

  test "Adds Team" do
    team = %Team{id: "red", name: "Red Team"}
    %Data{teams: [^team]} = %Data{} |> Data.add_team(team)
  end

  test "Removes Team" do
    team = %Team{id: "red", name: "Red Team"}

    %Data{teams: []} =
      %Data{teams: [team]}
      |> Data.remove_team(team)
  end

  test "Adds Player" do
    player = %Player{id: "bob", name: "Bob"}
    %Data{players: [^player]} = %Data{} |> Data.add_player(player)
  end

  test "Removes Player" do
    player = %Player{id: "bob", name: "Bob"}

    %Data{players: []} =
      %Data{players: [player]}
      |> Data.remove_player(player)
  end

  test "Sets And Gets Player Team" do
    player = %Player{id: "bob", name: "Bob"}
    team = %Team{id: "red", name: "Team Red"}

    team_id = team.id

    [%Player{team_id: ^team_id}] =
      %Data{players: [player], teams: [team]}
      |> Data.set_player_team(player, team)
      |> Data.get_players_by_team(team)

    ^team =
      %Data{players: [player], teams: [team]}
      |> Data.set_player_team(player, team)
      |> Data.get_team_by_player(player)
  end

  test "Set Player Team to nil" do
    player = %Player{id: "bob", name: "Bob"}
    team = %Team{id: "red", name: "Team Red"}

    team_id = team.id

    data =
      %Data{players: [player], teams: [team]}
      |> Data.set_player_team(player, team)

    [%Player{team_id: ^team_id}] = data |> Data.get_players_by_team(team)

    [] = data |> Data.set_player_team(player, nil) |> Data.get_players_by_team(team)
  end

  test "Add Round" do
    round = Round.empty()

    %Data{rounds: rounds} = %Data{} |> Data.add_round(round)

    assert length(rounds) == 1
  end

  test "Change round" do
    %Data{rounds: [changed_round | _]} =
      %Data{}
      |> Data.add_round(Round.empty())
      |> Data.add_round(Round.empty())
      |> Data.add_round(Round.empty())
      |> Data.update_round(0, &Round.set_code(&1, "red", [1, 2, 3]))
      |> Data.update_round(0, &Round.set_clues(&1, "red", ["one", "two", "three"]))
      |> Data.update_round(0, &Round.set_encipherer(&1, "red", %Player{id: "bob"}))
      |> Data.update_round(0, &Round.set_attempt(&1, "red", "blue", [1, 2, 3]))

    [1, 2, 3] = changed_round |> Round.get_code("red")
    ["one", "two", "three"] = changed_round |> Round.get_clues("red")
    %Player{id: "bob"} = changed_round |> Round.get_encipherer_id("red")
    [1, 2, 3] = changed_round |> Round.get_attempt("red", "blue")
  end

  test "Set target score" do
    %Data{target_points: 1337} = %Data{} |> Data.set_target_points(1337)
  end

  test "Encipherer pool" do
    players = [
      %Player{id: "bob", name: "Bob"},
      %Player{id: "bill", name: "Bill"},
      %Player{id: "sal", name: "Sal"},
      %Player{id: "mel", name: "Mel"}
    ]

    teams = [
      %Team{id: "red", name: "Team Red"},
      %Team{id: "blue", name: "Team Blue"}
    ]

    team_0_id = Enum.at(teams, 0).id
    team_1_id = Enum.at(teams, 1).id

    data =
      %Data{players: players, teams: teams}
      |> Data.set_player_team(Enum.at(players, 0), Enum.at(teams, 0))
      |> Data.set_player_team(Enum.at(players, 1), Enum.at(teams, 0))
      |> Data.set_player_team(Enum.at(players, 2), Enum.at(teams, 1))
      |> Data.set_player_team(Enum.at(players, 3), Enum.at(teams, 1))

    {encipherers, data} =
      teams
      |> List.foldl({%{}, data}, fn team, {encipherers, data} ->
        {encipherer, data} = data |> Data.pop_random_encipherer(team)
        {encipherers |> Map.put(team.id, encipherer), data}
      end)

    assert %Data{
             encipherer_pool_by_team_id: %{
               ^team_0_id => team_0_pool,
               ^team_1_id => team_1_pool
             }
           } = data

    %{
      ^team_0_id => team_0_encipherer,
      ^team_1_id => team_1_encipherer
    } = encipherers

    assert team_0_encipherer not in team_0_pool
    assert data |> Data.get_players_by_team_id(team_0_id) |> Enum.member?(team_0_encipherer)
    assert team_1_encipherer not in team_1_pool
    assert data |> Data.get_players_by_team_id(team_1_id) |> Enum.member?(team_1_encipherer)

    {_encipherers, data} =
      teams
      |> List.foldl({%{}, data}, fn team, {encipherers, data} ->
        {encipherer, data} = data |> Data.pop_random_encipherer(team)
        {encipherers |> Map.put(team.id, encipherer), data}
      end)

    assert [] = data.encipherer_pool_by_team_id[team_0_id]
    assert [] = data.encipherer_pool_by_team_id[team_0_id]
  end
end
