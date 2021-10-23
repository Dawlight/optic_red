defmodule OpticRedWeb.Live.SetupLive do
  use OpticRedWeb, :live_component

  alias OpticRed.Game.State
  alias OpticRed.Game.State.Data

  @default_assigns %{
    teams: [],
    players: [],
    player_team_map: %{},
    current_player_id: nil,
    game_state: nil
  }

  def mount(socket) do
    {:ok, assign(socket, @default_assigns)}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  def get_current_round(assigns) do
    game_state = assigns[:game_state]

    case game_state do
      nil ->
        nil

      %State{data: data} ->
        %Data{rounds: rounds} = data
        [current_round | _] = rounds
        current_round
    end
  end

  def readied?(assigns) do
    current_player_id = assigns[:current_player_id]
    game_state = assigns[:game_state]

    %State{data: %Data{ready_players: ready_players}} = game_state

    ready_players |> Enum.member?(current_player_id)
  end

  def readied_players(assigns) do
    game_state = assigns[:game_state]

    %State{data: %Data{ready_players: ready_players}} = game_state
    ready_players
  end

  def get_current_team_encipherer_id(assigns) do
    current_player_id = assigns[:current_player_id]
    player_team_map = assigns[:player_team_map]

    current_player_team_id = player_team_map[current_player_id]

    current_round = get_current_round(assigns)
    current_round[current_player_team_id].encipherer_player_id
  end
end
