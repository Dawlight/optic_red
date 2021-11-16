defmodule OpticRedWeb.Live.SetupLive do
  use OpticRedWeb, :live_component

  @default_assigns %{
    current_player_id: nil,
    game_state: nil
  }

  def mount(socket) do
    {:ok, assign(socket, @default_assigns)}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  def players_sorted_by_team(assigns) do
    players = assigns[:players]
    current_player_id = assigns[:current_player_id]
    player_team_map = assigns[:player_team_map]

    players
    |> Enum.sort_by(&(&1.id != current_player_id), &=/2)
    |> Enum.sort_by(&player_team_map[&1.id], &>=/2)
  end

  def game_startable?(assigns) do
    %{game_state: %{data: %{players: players}}} = assigns |> IO.inspect(label: "game_startable")

    team_players_map =
      players
      |> Enum.group_by(fn player -> player.team_id end, fn player -> player end)

    has_required_number_of_players =
      team_players_map
      |> Enum.all?(fn {_team_id, players} -> length(players) >= 2 end)

    Enum.count(team_players_map) >= 2 && has_required_number_of_players
  end

  def players(assigns) do
    %{game_state: %{data: %{players: players}}} = assigns
    players
  end

  def teams(assigns) do
    %{game_state: %{data: %{teams: teams}}} = assigns
    teams
  end
end
