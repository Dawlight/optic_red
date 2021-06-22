defmodule OpticRedWeb.Live.Room do
  use OpticRedWeb, :live_view

  alias Phoenix.PubSub

  @impl true
  def mount(params, session, socket) do
    %{"player_id" => player_id} = session
    %{"room_id" => room_id} = params

    case connected?(socket) do
      true ->
        socket = assign(socket, player_id: player_id, room_id: room_id)

        case OpticRed.Room.exists?(room_id) do
          false ->
            {:ok, push_redirect(socket, to: "/")}

          true ->
            case OpticRed.Room.join(room_id, player_id, "Player #{player_id}") do
              {:ok, _} ->
                # Welcome!
                subscribe_and_fetch_data(room_id, socket)

              {:error, :player_already_joined} ->
                # Welcome back!
                subscribe_and_fetch_data(room_id, socket)
            end
        end

      false ->
        {:ok, assign(socket, test: "Connecting..", players: [])}
    end
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("join_red", _params, %{assigns: assigns} = socket) do
    :ok = OpticRed.Game.join_game(assigns.room_id, assigns.player_id, :red)
    {:noreply, socket}
  end

  @impl true
  def handle_event("join_blue", _params, %{assigns: assigns} = socket) do
    :ok = OpticRed.Game.join_game(assigns.room_id, assigns.player_id, :blue)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:player_joined_team, player_id, team}, _from, socket) do
  end

  @impl true
  def handle_info({:player_joined_room, player}, %{assigns: assigns} = socket) do
    IO.inspect(player, label: "Player joined: ")
    {:noreply, assign(socket, players: [player | assigns.players])}
  end

  @impl true
  def handle_info({:player_left_room, player}, %{assigns: assigns} = socket) do
    IO.inspect(socket, label: "Player left: ")
    {:noreply, assign(socket, players: List.delete(assigns.players, player))}
  end

  @impl true
  def terminate(_, %{assigns: assigns} = socket) do
    IO.inspect(socket, label: "Terminate")
    OpticRed.Room.leave(assigns.room_id, assigns.player_id)
    PubSub.unsubscribe(OpticRed.PubSub, room_topic(assigns.room_id))
    :shutdown
  end

  defp subscribe_and_fetch_data(room_id, socket) do
    subscribe_to_room(room_id)
    subscribe_to_game(room_id)
    {:ok, players} = OpticRed.Room.get_players(room_id)
    {:ok, assign(socket, test: "Hello!", players: players)}
  end

  defp subscribe_to_room(room_id) do
    PubSub.subscribe(OpticRed.PubSub, room_topic(room_id))
  end

  defp subscribe_to_game(room_id) do
    PubSub.subscribe(OpticRed.PubSub, game_topic(room_id))
  end

  defp room_topic(room_id) do
    "room:#{room_id}"
  end

  defp game_topic(room_id) do
    "room:#{room_id}:game"
  end
end
