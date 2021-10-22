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
end
