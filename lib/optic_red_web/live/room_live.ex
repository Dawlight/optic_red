defmodule OpticRedWeb.Live.RoomLive do
  use OpticRedWeb, :live_view

  alias Phoenix.PubSub
  alias OpticRed.Game.State
  alias OpticRed.Game.State.Rules.Setup

  @default_assigns %{
    test: "Hello!",
    player_metadata: %{},
    current_player_id: nil,
    room_id: nil,
    game_state: nil,
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
            OpticRed.add_player(room_id, player_id, "Player #{player_id}")
            socket |> subscribe_and_fetch_data(room_id, session)
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

    player_metadata = get_player_metadata(room_id)
    {:noreply, socket |> assign(player_metadata: player_metadata)}
  end

  ###
  ### PubSub Messages
  ###

  @impl true
  def handle_info(event, socket) do
    %{assigns: %{game_state: game_state}} = socket

    new_game_state = State.apply_event(game_state, event)
    {:noreply, socket |> assign(game_state: new_game_state)}
  end

  ###
  ### DOM Events
  ###

  def game_data(assigns) do
    case assigns do
      %{game_state: %{data: data}} ->
        data

      _ ->
        %{}
    end
  end

  defp subscribe_and_fetch_data(socket, room_id, session) do
    subscribe_to_room(room_id)
    subscribe_to_game(room_id)

    %{"player_id" => current_player_id} = session

    {:ok, _} = track_presence(current_player_id, room_id)
    history = get_current_history(room_id)

    game_state = State.build_state(history, Setup.new())

    player_metadata = get_player_metadata(room_id)

    {:ok,
     assign(socket,
       current_player_id: current_player_id,
       history: history,
       game_state: game_state,
       player_metadata: player_metadata,
       loading: false,
       test: "Hello!"
     )}
  end

  defp track_presence(current_player_id, room_id) do
    OpticRed.Presence.track(
      self(),
      room_topic(room_id),
      current_player_id,
      %{status: :online}
    )
  end

  defp get_current_history(room_id) do
    case OpticRed.Room.get_current_history(room_id) do
      {:ok, history} ->
        history

      {:error, _} ->
        []
    end
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
