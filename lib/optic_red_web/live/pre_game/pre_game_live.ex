defmodule OpticRedWeb.Live.PreGameLive do
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

  def sort_players_by_team(players, player_team_map, current_player_id) do
    players
    |> Enum.sort_by(&(&1.id != current_player_id), &=/2)
    |> Enum.sort_by(&player_team_map[&1.id], &>=/2)
  end

  def game_startable?(player_team_map) do
    team_players_map =
      player_team_map
      |> Enum.group_by(&elem(&1, 1), &elem(&1, 0))

    has_required_number_of_players =
      team_players_map
      |> Enum.all?(fn {team_id, players} -> length(players) >= 2 end)

    Enum.count(team_players_map) >= 2 && has_required_number_of_players
  end
end
