defmodule OpticRedWeb.Live.Lobby do
  use OpticRedWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, test: "Hello!")}
  end

  @impl true
  def handle_event("new_game", _value, socket) do
    {:ok, game_id} = OpticRed.start_new_game()
    {:noreply, push_redirect(socket, to: "/game/#{game_id}")}
  end

  @impl true
  def handle_event("join_game", _value, socket) do
    {:noreply, socket}
  end
end
