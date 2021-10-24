defmodule OpticRedWeb.Live.EncipherLive do
  use OpticRedWeb, :live_component

  @default_assigns %{
    teams: [],
    players: [],
    player_team_map: %{},
    current_player_id: nil
  }

  def mount(socket) do
    {:ok, assign(socket, @default_assigns)}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  def code(assigns) do
    current_player_id = assigns[:current_player_id]
    player_team_map = assigns[:player_team_map]
    current_team_id = player_team_map[current_player_id]
    game_state = assigns[:game_state]

    [current_round | _] = game_state.data.rounds

    current_round[current_team_id].code
  end

  def words(assigns) do
    current_player_id = assigns[:current_player_id]
    player_team_map = assigns[:player_team_map]
    current_team_id = player_team_map[current_player_id]
    game_state = assigns[:game_state]

    game_state.data.team_words_map[current_team_id]
  end

  def get_encipher_player_name(assigns) do
    current_player_id = assigns[:current_player_id]
    player_team_map = assigns[:player_team_map]
    current_team_id = player_team_map[current_player_id]
    game_state = assigns[:game_state]
    player_map = game_state.data.player_map

    [current_round | _] = game_state.data.rounds

    encipher_player_id = current_round[current_team_id].encipherer_player_id
    player_map[encipher_player_id].name
  end

  def has_team_submitted?(assigns) do
    current_player_id = assigns[:current_player_id]
    player_team_map = assigns[:player_team_map]
    game_state = assigns[:game_state]

    [current_round | _] = game_state.data.rounds
    current_team_id = player_team_map[current_player_id]

    current_round[current_team_id].clues != nil
  end
end
