defmodule OpticRed.Room do
  use GenServer

  alias Phoenix.PubSub
  alias OpticRed.Game.State
  alias OpticRed.Game.State.Rules.Setup

  alias OpticRed.Game.ActionResult

  alias OpticRed.Game.Action.{
    AddTeam,
    AddPlayer,
    RemovePlayer,
    AssignPlayer,
    SetTargetPoints
  }

  alias OpticRed.Game.Model.{
    Data,
    Team,
    Player
  }

  @initial_state Setup.new()

  ###
  ### API
  ###

  def start_link(room_id) do
    GenServer.start_link(__MODULE__, room_id, name: {:via, :gproc, get_room_name(room_id)})
  end

  def create_new_game(room_id, target_points) do
    case :gproc.where(get_room_name(room_id)) do
      :undefined -> {:error, :room_not_found}
      pid -> GenServer.call(pid, {:create_new_game, target_points})
    end
  end

  def dispatch_actions(room_id, actions) do
    case :gproc.where(get_room_name(room_id)) do
      :undefined -> {:error, :room_not_found}
      pid -> GenServer.call(pid, {:dispatch_actions, actions})
    end
  end

  def exists?(room_id) do
    case :gproc.where(get_room_name(room_id)) do
      :undefined -> false
      _pid -> true
    end
  end

  def add_player(room_id, player_id, name) do
    case :gproc.where(get_room_name(room_id)) do
      :undefined -> false
      pid -> GenServer.call(pid, {:add_player, player_id, name})
    end
  end

  def remove_player(room_id, player_id) do
    case :gproc.where(get_room_name(room_id)) do
      :undefined -> {:error, :room_not_found}
      pid -> GenServer.call(pid, {:remove_player, player_id})
    end
  end

  def assign_player(room_id, player_id, team_id) do
    case :gproc.where(get_room_name(room_id)) do
      :undefined -> {:error, :room_not_found}
      pid -> GenServer.call(pid, {:assign_player, player_id, team_id})
    end
  end

  def get_current_history(room_id) do
    case :gproc.where(get_room_name(room_id)) do
      :undefined -> {:error, :room_not_found}
      pid -> GenServer.call(pid, :get_current_history)
    end
  end

  def get_players(room_id) do
    case :gproc.where(get_room_name(room_id)) do
      :undefined -> {:error, :room_not_found}
      pid -> GenServer.call(pid, :get_players)
    end
  end

  def player_exists?(room_id, player_id) do
    case :gproc.where(get_room_name(room_id)) do
      :undefined -> {:error, :room_not_found}
      pid -> GenServer.call(pid, {:player_exists?, player_id})
    end
  end

  ###
  ### GenServer Callbacks
  ###

  @impl GenServer
  def init(room_id) do
    initial_state = %{
      room_id: room_id,
      room_topic: "room:#{room_id}",
      histories: [do_create_new_game()]
    }

    {:ok, initial_state}
  end

  ##
  ## Manipulation
  ##

  @impl GenServer
  def handle_call(:create_new_game, _from, %{histories: histories} = data) do
    new_history = do_create_new_game()

    histories = [new_history | histories]
    {:reply, {:ok, new_history}, %{data | histories: histories}}
  end

  @impl GenServer
  def handle_call({:add_player, player_id, name}, _from, data) do
    {result, data} =
      %AddPlayer{id: player_id, name: name}
      |> handle_action(data)

    {:reply, {:ok, result}, data}
  end

  @impl GenServer
  def handle_call({:remove_player, player_id}, _from, data) do
    {result, data} =
      %RemovePlayer{id: player_id}
      |> handle_action(data)

    {:reply, {:ok, result}, data}
  end

  @impl GenServer
  def handle_call({:assign_player, player_id, team_id}, _from, data) do
    {result, data} =
      %AssignPlayer{player_id: player_id, team_id: team_id}
      |> handle_action(data)

    {:reply, {:ok, result}, data}
  end

  ##
  ## Retrieving
  ##

  @impl GenServer
  def handle_call(:get_current_history, _from, %{histories: histories} = data) do
    case histories do
      [current_history | _] -> {:reply, {:ok, current_history}, data}
      _ -> {:reply, {:error, :no_histories_found}, data}
    end
  end

  @impl GenServer
  def handle_call(:get_players, _from, %{players: players} = data) do
    {:reply, {:ok, players}, data}
  end

  @impl GenServer
  def handle_call({:player_exists?, player_id}, _from, %{players: players} = data) do
    case Enum.find(players, nil, fn player -> elem(player, 0) == player_id end) do
      nil ->
        {:reply, false, data}

      _ ->
        {:reply, true, data}
    end
  end

  ##
  ## Private
  ##

  defp do_create_new_game() do
    actions = [
      AddTeam.with(id: "red", name: "Red"),
      AddTeam.with(id: "blue", name: "Blue"),
      SetTargetPoints.with(points: 2)
    ]

    handle_actions(actions)
  end

  defp handle_actions(actions) do
    actions
    |> List.foldl([], fn action, history ->
      %ActionResult{events: events} =
        State.build_state(history, @initial_state)
        |> State.handle_action(action)

      history ++ events
    end)
  end

  defp handle_action(action, %{histories: histories, room_topic: room_topic} = data) do
    [history | _] = histories

    history
    |> State.build_state(@initial_state)
    |> State.handle_action(action)
    |> broadcast_events(room_topic)
    |> append_history(data)
  end

  defp append_history(%ActionResult{events: events} = result, %{histories: histories} = data) do
    histories = histories |> List.update_at(0, fn history -> history ++ events end)
    data = %{data | histories: histories}

    {result, data}
  end

  defp broadcast_events(%ActionResult{events: events} = result, topic) do
    for event <- events do
      broadcast(topic, event)
    end

    result
  end

  defp broadcast(topic, message) do
    PubSub.broadcast(OpticRed.PubSub, topic, message)
  end

  defp get_room_name(room_id) do
    {:n, :l, {:room, room_id}}
  end
end
