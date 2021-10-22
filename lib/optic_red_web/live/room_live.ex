defmodule OpticRedWeb.Live.RoomLive do
  use OpticRedWeb, :live_view

  alias Phoenix.PubSub
  alias OpticRed.Game.State.Team
  alias OpticRed.Game.State.Player

  @default_assigns %{
    test: "Hello!",
    players: [],
    teams: [%Team{id: "red", name: "Team Red"}, %Team{id: "blue", name: "Team Blue"}],
    player_team_map: %{},
    current_player_id: nil,
    room_id: nil
  }

  ###
  ### Mount and parameters
  ###

  @impl true
  def mount(params, session, socket) do
    %{"player_id" => player_id} = session
    %{"room_id" => room_id} = params

    case connected?(socket) do
      true ->
        socket = socket |> assign(current_player_id: player_id, room_id: room_id)

        case OpticRed.Room.exists?(room_id) do
          false ->
            {:ok, push_redirect(socket, to: "/")}

          true ->
            case OpticRed.add_player(room_id, player_id, "Player #{player_id}") do
              {:ok, _} ->
                socket |> subscribe_and_fetch_data(room_id, session)

              {:error, :player_already_joined} ->
                socket |> subscribe_and_fetch_data(room_id, session)
            end
        end

      false ->
        {:ok, assign(socket, @default_assigns)}
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
    :ok = OpticRed.assign_player(assigns.room_id, assigns.current_player_id, team_id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("leave_team", _values, %{assigns: assigns} = socket) do
    :ok = OpticRed.assign_player(assigns.room_id, assigns.current_player_id, nil)
    {:noreply, socket}
  end

  @impl true
  def handle_event("leave_game", _params, %{assigns: assigns} = socket) do
    :ok = OpticRed.assign_player(assigns.room_id, assigns.current_player_id, nil)
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
    {:noreply, socket |> assign(teams: [team | assigns[:teams]])}
  end

  @impl true
  def handle_info({:team_removed, team}, %{assigns: assigns} = socket) do
    ## TODO: Do something when team is removed
    {:noreply, socket}
  end

  @impl true
  def handle_info({:player_assigned, player_id, team_id}, %{assigns: assigns} = socket) do
    player_team_map = assigns[:player_team_map]
    ## TODO: Do something when player is assigned
    player_team_map =
      case team_id do
        nil ->
          {_, player_team_map} = player_team_map |> Map.pop(player_id)
          player_team_map

        _ ->
          player_team_map |> Map.put(player_id, team_id)
      end

    {:noreply, socket |> assign(player_team_map: player_team_map)}
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
    OpticRed.remove_player(assigns.room_id, assigns.current_player_id)
    PubSub.unsubscribe(OpticRed.PubSub, room_topic(assigns.room_id))
    :shutdown
  end

  ###
  ### View helpers
  ###

  def sort_players_by_team(players, player_team_map, current_player_id) do
    players
    |> Enum.sort_by(&(&1.id != current_player_id), &=/2)
    |> Enum.sort_by(&player_team_map[&1.id], &>=/2)
  end

  def game_startable?(player_team_map) do
    team_players_map =
      player_team_map
      |> Enum.group_by(&elem(&1, 1), &elem(&1, 0))
      |> IO.inspect(label: "GAME STARTABLE")

    has_required_number_of_players =
      team_players_map
      |> Enum.all?(fn {team_id, players} -> length(players) >= 2 end)
      |> IO.inspect(label: "TEAM PLAYERS MAP")

    Enum.count(team_players_map) |> IO.inspect(label: "number of teams") >= 2 &&
      has_required_number_of_players
  end

  ###
  ### Private
  ###

  defp subscribe_and_fetch_data(socket, room_id, session) do
    subscribe_to_room(room_id)
    subscribe_to_game(room_id)

    %{"player_id" => current_player_id} = session
    {:ok, players} = OpticRed.get_players(room_id)
    {:ok, teams} = OpticRed.get_teams(room_id)

    {:ok, player_team_map} = OpticRed.get_player_team_map(room_id)

    {:ok,
     assign(socket,
       test: "Hello!",
       players: players,
       teams: teams,
       player_team_map: player_team_map,
       current_player_id: current_player_id
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
