defmodule OpticRed.GameSateTest do
  use ExUnit.Case, async: false

  test "creates new state" do
    teams = [:red, :blue]
    state = OpticRed.Game.State.create_new(teams)

    %{
      current: :setup,
      data: %OpticRed.Game.State.Data{
        rounds: [],
        teams: ^teams,
        lead_team: :red,
        players: %{},
        score: %{red: 0, blue: 0}
      }
    } = state

    for {_, team_words} <- state.data.words do
      assert length(team_words) == 4
    end
  end

  test "assigns player" do
    player_id = "player1"

    state = OpticRed.Game.State.create_new([:red, :blue])

    state = OpticRed.Game.State.set_player(state, player_id, :red)
    assert Map.get(state.data.players, player_id) == :red

    state = OpticRed.Game.State.set_player(state, player_id, :blue)
    assert Map.get(state.data.players, player_id) == :blue
  end

  test "creates new round" do
    player_1_id = "player1"
    player_2_id = "player2"
    player_3_id = "player3"
    player_4_id = "player4"

    state = OpticRed.Game.State.create_new([:red, :blue])

    state = OpticRed.Game.State.set_player(state, player_1_id, :red)
    state = OpticRed.Game.State.set_player(state, player_2_id, :red)
    state = OpticRed.Game.State.set_player(state, player_3_id, :blue)
    state = OpticRed.Game.State.set_player(state, player_4_id, :blue)

    %{current: :encipher} = OpticRed.Game.State.new_round(state)
  end

  test "can't create new round unless there are enough players" do
    player_1_id = "player1"
    player_2_id = "player2"
    player_4_id = "player4"

    state = OpticRed.Game.State.create_new([:red, :blue])

    state = OpticRed.Game.State.set_player(state, player_1_id, :red)
    state = OpticRed.Game.State.set_player(state, player_2_id, :red)
    state = OpticRed.Game.State.set_player(state, player_4_id, :blue)

    {:error, _} = OpticRed.Game.State.new_round(state)
  end

  test "submits clues" do
    player_1_id = "player1"
    player_2_id = "player2"
    player_3_id = "player3"
    player_4_id = "player4"

    state = OpticRed.Game.State.create_new([:red, :blue])

    state =
      state
      |> OpticRed.Game.State.set_player(player_1_id, :red)
      |> OpticRed.Game.State.set_player(player_2_id, :red)
      |> OpticRed.Game.State.set_player(player_3_id, :blue)
      |> OpticRed.Game.State.set_player(player_4_id, :blue)

    state = OpticRed.Game.State.new_round(state)

    state = OpticRed.Game.State.submit_clues(state, :red, ["Thick", "Big", "Gone"])

    assert List.first(state.data.rounds)[:red].clues == ["Thick", "Big", "Gone"]

  end

  test "starts decipher phase when all clues have been submitted" do
    player_1_id = "player1"
    player_2_id = "player2"
    player_3_id = "player3"
    player_4_id = "player4"

    state = OpticRed.Game.State.create_new([:red, :blue])

    state =
      state
      |> OpticRed.Game.State.set_player(player_1_id, :red)
      |> OpticRed.Game.State.set_player(player_2_id, :red)
      |> OpticRed.Game.State.set_player(player_3_id, :blue)
      |> OpticRed.Game.State.set_player(player_4_id, :blue)

    state = OpticRed.Game.State.new_round(state)

    state = OpticRed.Game.State.submit_clues(state, :red, ["Thick", "Big", "Gone"])
    %{current: :decipher} = OpticRed.Game.State.submit_clues(state, :blue, ["Thin", "Small", "Home"])

  end
end
