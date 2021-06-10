defmodule OpticRed.GameSateTest do
  use ExUnit.Case, async: false

  setup do
    game_id = 1
    teams = [:red, :blue]
    {:ok, state} = OpticRed.GameState.start_link(%{game_id: game_id, teams: teams})
    %{game_id: game_id, teams: teams, state: state}
  end

  test "accepts clues", state do
    clues = ["a", "b", "c"]
    {:ok, _} = OpticRed.GameState.submit_clues(state.game_id, :red, clues)
    {:ok, current_round} = OpticRed.GameState.get_current_round(state.game_id)

    assert current_round[:red].clues === clues
  end

  test "accepts attempts", state do
    red_clues = ["a", "b", "c"]
    blue_clues = ["1", "2", "3"]
    red_attempt = ["x", "y", "z"]
    {:ok, _} = OpticRed.GameState.submit_clues(state.game_id, :red, red_clues)
    {:ok, _} = OpticRed.GameState.submit_clues(state.game_id, :blue, blue_clues)

    {:ok, _} = OpticRed.GameState.submit_attempt(state.game_id, :red, red_attempt)

    {:ok, current_state} = OpticRed.GameState.get_game_state(state.game_id)
    {:ok, current_round} = OpticRed.GameState.get_current_round(state.game_id)

    assert current_round[:red].attempts[current_state.lead_team] === red_attempt
  end

  test "calculates correct score", state do
    red_clues = ["a", "b", "c"]
    blue_clues = ["1", "2", "3"]
    red_attempt = [1, 3, 7]
    {:ok, current_round} = OpticRed.GameState.get_current_round(state.game_id)

    {:ok, _} = OpticRed.GameState.submit_clues(state.game_id, :red, red_clues)
    {:ok, _} = OpticRed.GameState.submit_clues(state.game_id, :blue, blue_clues)

    {:ok, _} = OpticRed.GameState.submit_attempt(state.game_id, :red, red_attempt)
    {:ok, _} = OpticRed.GameState.submit_attempt(state.game_id, :blue, current_round[:red].code)
    {:ok, _} = OpticRed.GameState.submit_attempt(state.game_id, :red, red_attempt)
    {:ok, _} = OpticRed.GameState.submit_attempt(state.game_id, :blue, current_round[:blue].code)

    {:ok, current_state} = OpticRed.GameState.get_game_state(state.game_id)

    assert current_state.score[:red] == -2
    assert current_state.score[:blue] == 1
  end
end
