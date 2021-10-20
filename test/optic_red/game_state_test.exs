defmodule OpticRed.GameSateTest do
  use ExUnit.Case, async: false

  alias OpticRed.Game.State

  test "creates new state" do
    teams = [%State.Team{id: :red}, %State.Team{id: :blue}]
    state = State.create_new(teams)

    %{
      current: :setup,
      data: %State.Data{
        rounds: [],
        teams: ^teams,
        lead_team_id: :red,
        player_map: %{},
        team_score_map: %{red: 0, blue: 0}
      }
    } = state

    for {_, team_words} <- state.data.team_words_map do
      assert length(team_words) == 4
    end
  end

  test "assigns player" do
    teams = [%State.Team{id: :red}, %State.Team{id: :blue}]
    state = State.create_new(teams)

    player_id = "player1"

    state = State.add_player(state, player_id, :red)
    assert Map.get(state.data.player_team_map, player_id) == :red

    state = State.add_player(state, player_id, :blue)
    assert Map.get(state.data.player_team_map, player_id) == :blue
  end

  test "creates new round" do
    teams = [%State.Team{id: :red}, %State.Team{id: :blue}]
    state = State.create_new(teams)

    player_1_id = "player1"
    player_2_id = "player2"
    player_3_id = "player3"
    player_4_id = "player4"

    state = State.add_player(state, player_1_id, :red)
    state = State.add_player(state, player_2_id, :red)
    state = State.add_player(state, player_3_id, :blue)
    state = State.add_player(state, player_4_id, :blue)

    %{current: :encipher} = State.new_round(state)
  end

  test "can't create new round unless there are enough players" do
    teams = [%State.Team{id: :red}, %State.Team{id: :blue}]
    state = State.create_new(teams)

    player_1_id = "player1"
    player_2_id = "player2"
    player_4_id = "player4"

    state = State.add_player(state, player_1_id, :red)
    state = State.add_player(state, player_2_id, :red)
    state = State.add_player(state, player_4_id, :blue)

    {:error, _} = State.new_round(state)
  end

  test "submits clues" do
    teams = [%State.Team{id: :red}, %State.Team{id: :blue}]
    state = State.create_new(teams)

    player_1_id = "player1"
    player_2_id = "player2"
    player_3_id = "player3"
    player_4_id = "player4"

    state =
      state
      |> State.add_player(player_1_id, :red)
      |> State.add_player(player_2_id, :red)
      |> State.add_player(player_3_id, :blue)
      |> State.add_player(player_4_id, :blue)

    state = State.new_round(state)

    %{current: :encipher} = state

    state = State.submit_clues(state, :red, ["Thick", "Big", "Gone"])

    assert List.first(state.data.rounds)[:red].clues == ["Thick", "Big", "Gone"]
  end

  test "starts decipher phase when all clues have been submitted" do
    teams = [%State.Team{id: :red}, %State.Team{id: :blue}]
    state = State.create_new(teams)

    player_1_id = "player1"
    player_2_id = "player2"
    player_3_id = "player3"
    player_4_id = "player4"

    state =
      state
      |> State.add_player(player_1_id, :red)
      |> State.add_player(player_2_id, :red)
      |> State.add_player(player_3_id, :blue)
      |> State.add_player(player_4_id, :blue)

    state = State.new_round(state)

    state = State.submit_clues(state, :red, ["Thick", "Big", "Gone"])
    %{current: :encipher} = state

    %{current: :decipher} = State.submit_clues(state, :blue, ["Thin", "Small", "Home"])
  end

  test "switches lead team when all teams have submitted attempts" do
    teams = [%State.Team{id: :red}, %State.Team{id: :blue}]
    state = State.create_new(teams)

    player_1_id = "player1"
    player_2_id = "player2"
    player_3_id = "player3"
    player_4_id = "player4"

    state =
      state
      |> State.add_player(player_1_id, :red)
      |> State.add_player(player_2_id, :red)
      |> State.add_player(player_3_id, :blue)
      |> State.add_player(player_4_id, :blue)

    state = State.new_round(state)

    state = State.submit_clues(state, :red, ["Thick", "Big", "Gone"])
    %{current: :encipher} = state
    state = State.submit_clues(state, :blue, ["Thin", "Small", "Home"])
    %{current: :decipher} = state

    state = State.submit_attempt(state, :red, [1, 2, 3])

    %State.State{current: :decipher, data: %State.Data{lead_team_id: :blue}} =
      State.submit_attempt(state, :blue, [3, 2, 1])
  end

  test "starts new round when all attempts have been submitted" do
    teams = [%State.Team{id: :red}, %State.Team{id: :blue}]
    state = State.create_new(teams)

    player_1_id = "player1"
    player_2_id = "player2"
    player_3_id = "player3"
    player_4_id = "player4"

    state =
      state
      |> State.add_player(player_1_id, :red)
      |> State.add_player(player_2_id, :red)
      |> State.add_player(player_3_id, :blue)
      |> State.add_player(player_4_id, :blue)

    state = State.new_round(state)

    state = state |> State.submit_clues(:red, ["Thick", "Big", "Gone"])
    %{current: :encipher} = state
    state = state |> State.submit_clues(:blue, ["Thin", "Small", "Home"])
    %{current: :decipher} = state

    state = State.submit_attempt(state, :red, [1, 2, 3])
    state = State.submit_attempt(state, :blue, [3, 2, 1])

    state = State.submit_attempt(state, :red, [2, 2, 2])
    state = State.submit_attempt(state, :blue, [3, 3, 3])

    %{current: :encipher} = state
  end

  test "ends game when a team has reached the set amount of points" do
    teams = [%State.Team{id: :red}, %State.Team{id: :blue}]
    state = State.create_new(teams, 1)

    player_1_id = "player1"
    player_2_id = "player2"
    player_3_id = "player3"
    player_4_id = "player4"

    state =
      state
      |> State.add_player(player_1_id, :red)
      |> State.add_player(player_2_id, :red)
      |> State.add_player(player_3_id, :blue)
      |> State.add_player(player_4_id, :blue)

    state = State.new_round(state)

    state = State.submit_clues(state, :red, ["Thick", "Big", "Gone"])
    %{current: :encipher} = state

    state = %{current: :decipher} = State.submit_clues(state, :blue, ["Thin", "Small", "Home"])

    %{data: %{rounds: [current_round | _]}} = state

    state = State.submit_attempt(state, :red, [1, 2, 3])
    state = State.submit_attempt(state, :blue, current_round[:red].code)
    state = State.submit_attempt(state, :red, [2, 2, 2])
    state = State.submit_attempt(state, :blue, current_round[:blue].code)

    %{current: :game_end} = state
  end
end
