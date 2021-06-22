defmodule OpticRed.Room do
  use GenServer

  alias Phoenix.PubSub

  ###
  ### API
  ###

  def start_link(room_id) do
    GenServer.start_link(__MODULE__, room_id, name: {:via, :gproc, get_room_name(room_id)})
  end

  def exists?(room_id) do
    case :gproc.where(get_room_name(room_id))
         |> IO.inspect(label: "Does room #{room_id} exsist?") do
      :undefined -> false
      _pid -> true
    end
  end

  def has_joined?(room_id, player_id) do
    case :gproc.where(get_room_name(room_id)) do
      :undefined -> {:error, :room_not_found}
      pid -> GenServer.call(pid, {:has_joined, player_id})
    end
  end

  def join(room_id, player_id, name) do
    case :gproc.where(get_room_name(room_id)) do
      :undefined -> false
      pid -> GenServer.call(pid, {:join, player_id, name})
    end
  end

  def leave(room_id, player_id) do
    case :gproc.where(get_room_name(room_id)) do
      :undefined -> {:error, :room_not_found}
      pid -> GenServer.call(pid, {:leave, player_id})
    end
  end

  def get_players(room_id) do
    case :gproc.where(get_room_name(room_id)) do
      :undefined -> {:error, :room_not_found}
      pid -> GenServer.call(pid, :get_players)
    end
  end

  ###
  ### GenServer Callbacks
  ###

  @impl GenServer
  def init(room_id) do
    IO.inspect('Init run!')

    initial_state = %{room_id: room_id, players: [], room_topic: "room:#{room_id}"}

    {:ok, initial_state}
  end

  @impl GenServer

  def handle_call({:join, player_id, name}, _from, %{players: players} = data) do
    player = %{id: player_id, name: name} |> IO.inspect(label: "Player trying to join")

    case Enum.member?(players, player) |> IO.inspect(label: "Player already joined?") do
      true ->
        {:reply, {:error, :player_already_joined}, data}

      false ->
        players = Enum.uniq([player | players])
        PubSub.broadcast(OpticRed.PubSub, data.room_topic, {:player_joined_room, player})
        {:reply, {:ok, player}, %{data | players: players}}
    end
  end

  def handle_call({:leave, player_id}, _from, %{players: players} = data) do
    case Enum.find(players, nil, fn player -> player.id == player_id end) do
      nil ->
        {:reply, {:error, :player_not_found}, data}

      player ->
        players = List.delete(players, player)
        PubSub.broadcast(OpticRed.PubSub, data.room_topic, {:player_left_room, player})
        {:reply, {:ok, player}, %{data | players: players}}
    end
  end

  def handle_call({:has_joined, player_id}, _from, %{players: players} = data) do
    case Enum.find(players, nil, fn player -> elem(player, 0) == player_id end) do
      nil ->
        {:reply, false, data}

      _ ->
        {:reply, true, data}
    end
  end

  def handle_call(:get_players, _from, %{players: players} = data) do
    {:reply, {:ok, players}, data}
  end

  defp get_room_name(room_id) do
    {:n, :l, {:room, room_id}}
  end
end
