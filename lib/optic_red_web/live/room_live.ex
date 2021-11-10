defmodule OpticRedWeb.Live.RoomLive do
  use OpticRedWeb, :live_view

  alias Phoenix.PubSub

  @default_assigns %{
    test: "Hello!",
    players: [],
    player_metadata: %{},
    current_player_id: nil,
    room_id: nil,
    history: [],
    loading: true
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
  ### Presence
  ###

  def handle_info(%{event: "presence_diff"}, socket) do
    %{assigns: %{room_id: room_id}} = socket

    player_metadata = get_player_metadata(room_id) |> IO.inspect(label: "presence_diff")
    {:noreply, socket |> assign(player_metadata: player_metadata)}
  end

  ###
  ### PubSub Messages
  ###

  @impl true
  def handle_info({:game_created, game_state}, socket) do
    {:noreply, socket |> assign(game_state: game_state, loading: false)}
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
  def handle_info({:player_ready_changed, game_state}, socket) do
    {:noreply, assign(socket, game_state: game_state)}
  end

  @impl true
  def handle_info({:clues_submitted, game_state}, socket) do
    {:noreply,
     assign(socket, game_state: game_state |> IO.inspect(label: "C L U E S  S U B M I T T E D"))}
  end

  @impl true
  def handle_info({:attempt_submitted, game_state}, socket) do
    {:noreply,
     assign(socket,
       game_state: game_state |> IO.inspect(label: "A T T E M P T  S U B M I T T E D")
     )}
  end

  @impl true
  def handle_info({:new_round, game_state}, socket) do
    {:noreply,
     assign(socket,
       game_state: game_state |> IO.inspect(label: "N E W   R O U N D")
     )}
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
  def handle_event("start_game", _value, %{assigns: assigns} = socket) do
    {:ok, _game_state} = OpticRed.create_new_game(assigns.room_id, 2)
    {:noreply, socket |> assign(loading: true)}
  end

  @impl true
  def handle_event("leave_game", _params, %{assigns: assigns} = socket) do
    :ok = OpticRed.assign_player(assigns.room_id, assigns.current_player_id, nil)
    {:noreply, socket}
  end

  @impl true
  def handle_event("ready_toggle", %{"ready" => ready?} = _values, %{assigns: assigns} = socket) do
    case ready? do
      "true" ->
        {:ok, _} = OpticRed.set_player_ready(assigns.room_id, assigns.current_player_id, true)
        {:noreply, socket}

      "false" ->
        {:ok, _} = OpticRed.set_player_ready(assigns.room_id, assigns.current_player_id, false)
        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("submit_clues", %{"clues" => clues}, %{assigns: assigns} = socket) do
    clues = clues |> Enum.map(fn {_, clue} -> clue end)

    current_player_id = assigns[:current_player_id]
    player_team_map = assigns[:player_team_map]

    current_team_id = player_team_map[current_player_id]

    {:ok, _} = OpticRed.submit_clues(assigns.room_id, current_team_id, clues)
    {:noreply, socket}
  end

  @impl true
  def handle_event("submit_attempt", values, %{assigns: assigns} = socket) do
    %{"attempt_numbers" => attempt_numbers} = values
    attempt_numbers = attempt_numbers |> Enum.map(fn {_, number} -> number end)

    current_player_id = assigns[:current_player_id]
    player_team_map = assigns[:player_team_map]

    current_team_id = player_team_map[current_player_id]

    {:ok, _} = OpticRed.submit_attempt(assigns.room_id, current_team_id, attempt_numbers)
    {:noreply, socket}
  end

  @impl true
  def handle_event("next_round", _values, %{assigns: assigns} = socket) do
    {:ok, _} = OpticRed.new_round(assigns.room_id)
    {:noreply, socket}
  end

  ###
  ### Terminate
  ### TODO: Monitor instead of terminate

  @impl true
  def terminate(_, %{assigns: assigns}) do
    PubSub.unsubscribe(OpticRed.PubSub, room_topic(assigns.room_id))
    :shutdown
  end

  ###
  ### View helpers
  ###

  # def get_player_view(assigns) do
  #   current_player_id = assigns[:current_player_id]
  #   player_team_map = assigns[:player_team_map]
  #   game_state = assigns[:game_state]

  #   current_team_id = player_team_map[current_player_id]
  # end

  # def page_loader_classes(assigns) do
  #   case assigns[:loading] do
  #     false ->
  #       case get_player_view(assigns) do
  #         nil -> "pageloader is-active"
  #         _ -> "pageloader"
  #       end

  #     true ->
  #       "pageloader is-active"

  #     _ ->
  #       "pageloader"
  #   end
  # end

  ###
  ### Private
  ###

  defp subscribe_and_fetch_data(socket, room_id, session) do
    subscribe_to_room(room_id)
    subscribe_to_game(room_id)

    %{"player_id" => current_player_id} = session
    {:ok, players} = OpticRed.get_players(room_id)
    # {:ok, teams} = OpticRed.get_teams(room_id)
    # {:ok, player_team_map} = OpticRed.get_player_team_map(room_id)

    {:ok, _} =
      OpticRed.Presence.track(
        self(),
        room_topic(room_id),
        current_player_id,
        %{status: :online}
      )

    # game_state =
    #   case OpticRed.get_game_state(room_id) do
    #     {:ok, game_state} -> game_state
    #     _ -> nil
    #   end

    player_metadata = get_player_metadata(room_id)

    {:ok,
     assign(socket,
       test: "Hello!",
       players: players,
       player_metadata: player_metadata,
       #  teams: teams,
       #  player_team_map: player_team_map,
       current_player_id: current_player_id,
       #  game_state: game_state,
       loading: false
     )}
  end

  defp get_player_metadata(room_id) do
    OpticRed.Presence.list(room_topic(room_id))
    |> Enum.map(fn {player_id, data} ->
      {player_id,
       data[:metas]
       |> List.first()}
    end)
    |> Map.new()
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
