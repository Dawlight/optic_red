defmodule OpticRedWeb.Live.Room do
  use OpticRedWeb, :live_view

  alias Phoenix.PubSub

  ###
  ### Mount and parameters
  ###

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
                subscribe_and_fetch_data(room_id, session, socket)

              {:error, :player_already_joined} ->
                # Welcome back!
                subscribe_and_fetch_data(room_id, session, socket)
            end
        end

      false ->
        {:ok,
         assign(socket,
           test: "Connecting..",
           players: [],
           current_player: nil,
           game_state: %{current: :unknown, data: %{}}
         )}
    end
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  ###
  ### DOM Events
  ###

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
  def handle_event("leave_game", _params, %{assigns: assigns} = socket) do
    :ok = OpticRed.Game.leave_game(assigns.room_id, assigns.player_id)
    {:noreply, socket}
  end

  ###
  ### PubSub Messages
  ###

  @impl true
  def handle_info({:game_state_updated, game_state}, socket) do
    {:noreply, assign(socket, game_state: game_state)}
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

  ###
  ### Terminate
  ### TODO: Monitor instead of terminate

  @impl true
  def terminate(_, %{assigns: assigns} = socket) do
    IO.inspect(socket, label: "Terminate")
    OpticRed.Room.leave(assigns.room_id, assigns.player_id)
    PubSub.unsubscribe(OpticRed.PubSub, room_topic(assigns.room_id))
    :shutdown
  end

  ###
  ### View helpers
  ###

  def get_players_in_team(%{data: data}, players, nil) do
    Enum.filter(players, fn %{id: id} -> not Enum.member?(Map.keys(data.players), id) end)
  end

  def get_players_in_team(%{data: data}, players, team) do
    IO.inspect(players, label: "Players")
    IO.inspect(data, label: "Data")

    Enum.filter(players, fn %{id: id} ->
      Enum.member?(Map.keys(data.players), id) and data.players[id] == team
    end)
  end

  ###
  ### Private
  ###

  defp subscribe_and_fetch_data(room_id, session, socket) do
    subscribe_to_room(room_id)
    subscribe_to_game(room_id)

    %{"player_id" => current_player} = session
    {:ok, players} = OpticRed.Room.get_players(room_id)
    {:ok, game_state} = OpticRed.Game.get_state(room_id)

    {:ok,
     assign(socket,
       test: "Hello!",
       players: players,
       game_state: game_state,
       current_player: current_player
     )}
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
