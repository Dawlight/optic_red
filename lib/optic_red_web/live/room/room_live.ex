defmodule OpticRedWeb.Live.RoomLive do
  use OpticRedWeb, :live_view

  alias Phoenix.PubSub

  @teams [{"red", "Red"}, {"blue", "Blue"}]

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
            case OpticRed.add_player(room_id, player_id, "Player #{player_id}") do
              {:ok, _} ->
                # Welcome!
                socket |> subscribe_and_fetch_data(room_id, session)

              {:error, :player_already_joined} ->
                # Welcome back!
                socket |> subscribe_and_fetch_data(room_id, session)
            end
        end

      false ->
        {:ok,
         assign(socket,
           test: "Connecting..",
           players: [],
           current_player: nil,
           game_state: %{current: :unknown, data: %OpticRed.Game.State.Data{}},
           teams: @teams
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
  def handle_event("join_team", %{"team_id" => team_id}, %{assigns: assigns} = socket) do
    :ok = OpticRed.assign_player(assigns.room_id, assigns.player_id, team_id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("leave_game", _params, %{assigns: assigns} = socket) do
    :ok = OpticRed.remove_player(assigns.room_id, assigns.player_id)
    {:noreply, socket}
  end

  ###
  ### PubSub Messages
  ###

  @impl true
  def handle_info({:game_created, game_state}, %{assigns: assigns} = socket) do
    ## TODO: Do something when game starts
    {:noreply, socket}
  end

  @impl true
  def handle_info({:player_added, player}, %{assigns: assigns} = socket) do
    {:noreply, assign(socket, players: [player | assigns.players])}
  end

  @impl true
  def handle_info({:player_removed, player}, %{assigns: assigns} = socket) do
    {:noreply, assign(socket, players: List.delete(assigns.players, player))}
  end

  @impl true
  def handle_info({:team_added, team}, %{assigns: assigns} = socket) do
    ## TODO: Do something when team is added
    {:noreply, socket}
  end

  @impl true
  def handle_info({:team_removed, team}, %{assigns: assigns} = socket) do
    ## TODO: Do something when team is removed
    {:noreply, socket}
  end

  @impl true
  def handle_info({:player_assigned, player_id, team_id}, %{assigns: assigns} = socket) do
    ## TODO: Do something when player is assigned
    {:noreply, socket}
  end

  @impl true
  def handle_info({:game_state_updated, game_state}, socket) do
    {:noreply, assign(socket, game_state: game_state)}
  end

  ###
  ### Terminate
  ### TODO: Monitor instead of terminate

  @impl true
  def terminate(_, %{assigns: assigns} = socket) do
    IO.inspect(socket, label: "Terminate")
    OpticRed.remove_player(assigns.room_id, assigns.player_id)
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
    Enum.filter(players, fn %{id: id} ->
      Enum.member?(Map.keys(data.players), id) and data.players[id] == team
    end)
  end

  def is_team_joinable?(%{data: data}, teams, team) do
    ## TODO: Actual logic
    true
  end

  ###
  ### Private
  ###

  defp subscribe_and_fetch_data(socket, room_id, session) do
    subscribe_to_room(room_id)
    subscribe_to_game(room_id)

    %{"player_id" => current_player} = session
    {:ok, players} = OpticRed.get_players(room_id)

    game_state =
      case OpticRed.get_game_state(room_id) do
        {:ok, game_state} -> game_state
        {:error, _} -> nil
      end

    {:ok,
     assign(socket,
       test: "Hello!",
       players: players,
       game_state: game_state,
       current_player: current_player,
       teams: @teams
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
