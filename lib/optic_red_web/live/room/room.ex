defmodule OpticRedWeb.Live.Room do
  use OpticRedWeb, :live_view

  alias Phoenix.PubSub

  @impl true
  def mount(params, session, socket) do
    IO.inspect(session, label: "session")
    %{"player_id" => player_id} = session
    %{"room_id" => room_id} = params

    if connected?(socket) do
      socket = assign(socket, player_id: player_id)
      socket = assign(socket, room_id: room_id)

      case OpticRed.Room.exists?(room_id) |> IO.inspect(label: "Does room exist?") do
        false ->
          {:ok, push_redirect(socket, to: "/")}

        true ->
          case OpticRed.Room.join(room_id, player_id, "Player #{player_id}") do
            {:ok, _} ->
              PubSub.subscribe(OpticRed.PubSub, "room:#{room_id}")
              {:ok, players} = OpticRed.Room.get_players(room_id)
              {:ok, assign(socket, test: "Hello!", players: players)}

            {:error, :player_already_joined} ->
              PubSub.subscribe(OpticRed.PubSub, "room:#{room_id}")
              {:ok, players} = OpticRed.Room.get_players(room_id)
              {:ok, assign(socket, test: "Hello", players: players)}
          end
      end
    else
      {:ok, assign(socket, test: "Default text", players: [])}
    end
  end

  @impl true
  def handle_info({:player_joined, player}, %{assigns: assigns} = socket) do
    IO.inspect(player, label: "Player joined: ")
    {:noreply, assign(socket, players: [player | assigns.players])}
  end

  @impl true
  def handle_info({:player_left, player}, %{assigns: assigns} = socket) do
    IO.inspect(socket, label: "Player left: ")
    {:noreply, assign(socket, players: List.delete(assigns.players, player))}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def terminate(_, %{assigns: assigns} = socket) do
    IO.inspect(socket, label: "Terminate")
    OpticRed.Room.leave(assigns.room_id, assigns.player_id)
    PubSub.unsubscribe(OpticRed.PubSub, "room:#{assigns.room_id}")
    :shutdown
  end
end
