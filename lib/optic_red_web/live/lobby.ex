defmodule OpticRedWeb.Live.Lobby do
  use OpticRedWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, test: "Hello!")}
  end

  @impl true
  def handle_event("new_room", _value, socket) do
    {:ok, room_id} = OpticRed.create_new_room()
    {:noreply, push_redirect(socket, to: "/room/#{room_id}")}
  end

  @impl true
  def handle_event("join_room", _value, socket) do
    {:noreply, socket}
  end
end
