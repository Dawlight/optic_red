defmodule OpticRed.Room do
  use GenServer

  alias Phoenix.PubSub
  alias OpticRed.Game.State.Team
  alias OpticRed.Game.State.Player

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

  def add_team(room_id, team_id, name) do
    case :gproc.where(get_room_name(room_id)) do
      :undefined -> false
      pid -> GenServer.call(pid, {:add_team, team_id, name})
    end
  end

  def remove_team(room_id, team_id) do
    case :gproc.where(get_room_name(room_id)) do
      :undefined -> false
      pid -> GenServer.call(pid, {:remove_team, team_id})
    end
  end

  def assign_player(room_id, player_id, team_id) do
    case :gproc.where(get_room_name(room_id)) do
      :undefined -> false
      pid -> GenServer.call(pid, {:assign_player, player_id, team_id})
    end
  end

  def create_new_game(room_id, target_score) do
    case :gproc.where(get_room_name(room_id)) do
      :undefined -> {:error, :room_not_found}
      pid -> GenServer.call(pid, {:create_new_game, target_score})
    end
  end

  def get_current_game(room_id) do
    case :gproc.where(get_room_name(room_id)) do
      :undefined -> {:error, :room_not_found}
      pid -> GenServer.call(pid, :get_current_game)
    end
  end

  def get_players(room_id) do
    case :gproc.where(get_room_name(room_id)) do
      :undefined -> {:error, :room_not_found}
      pid -> GenServer.call(pid, :get_players)
    end
  end

  def get_teams(room_id) do
    case :gproc.where(get_room_name(room_id)) do
      :undefined -> {:error, :room_not_found}
      pid -> GenServer.call(pid, :get_teams)
    end
  end

  def get_player_team_map(room_id) do
    case :gproc.where(get_room_name(room_id)) do
      :undefined -> {:error, :room_not_found}
      pid -> GenServer.call(pid, :get_player_team_map)
    end
  end

  def has_joined?(room_id, player_id) do
    case :gproc.where(get_room_name(room_id)) do
      :undefined -> {:error, :room_not_found}
      pid -> GenServer.call(pid, {:has_joined, player_id})
    end
  end

  ###
  ### GenServer Callbacks
  ###

  @impl GenServer
  def init(room_id) do
    IO.inspect('Init run!')

    initial_state = %{
      room_id: room_id,
      players: [],
      teams: [],
      player_team_map: %{},
      room_topic: "room:#{room_id}",
      games: []
    }

    {:ok, initial_state}
  end

  ##
  ## Manipulation
  ##

  @impl GenServer
  def handle_call({:add_player, player_id, name}, _from, %{players: players} = data) do
    player = %Player{id: player_id, name: name} |> IO.inspect(label: "Player trying to join")

    case Enum.member?(players, player) |> IO.inspect(label: "Player already joined?") do
      true ->
        {:reply, {:error, :player_already_joined}, data}

      false ->
        players = Enum.uniq([player | players])
        PubSub.broadcast(OpticRed.PubSub, data.room_topic, {:player_added, player})
        {:reply, {:ok, player}, %{data | players: players}}
    end
  end

  @impl GenServer
  def handle_call({:remove_player, player_id}, _from, %{players: players} = data) do
    case Enum.find(players, nil, fn player -> player.id == player_id end) do
      nil ->
        {:reply, {:error, :player_not_found}, data}

      player ->
        players = players |> List.delete(player)
        PubSub.broadcast(OpticRed.PubSub, data.room_topic, {:player_removed, player})
        {:reply, {:ok, player}, %{data | players: players}}
    end
  end

  @impl GenServer
  def handle_call({:add_team, team_id, name}, _from, %{teams: teams} = data) do
    team = %Team{id: team_id, name: name} |> IO.inspect(label: "Trying to add team")

    case Enum.member?(teams, team) |> IO.inspect(label: "Team already added?") do
      true ->
        {:reply, {:error, :team_already_exists}, data}

      false ->
        teams = Enum.uniq([team | teams])
        PubSub.broadcast(OpticRed.PubSub, data.room_topic, {:team_added, team})
        {:reply, {:ok, team}, %{data | teams: teams}}
    end
  end

  @impl GenServer
  def handle_call({:remove_team, team_id}, _from, %{teams: teams} = data) do
    case Enum.find(teams, nil, fn team -> team.id == team_id end) do
      nil ->
        {:reply, {:error, :team_not_found}, data}

      team ->
        teams = teams |> List.delete(team)
        PubSub.broadcast(OpticRed.PubSub, data.room_topic, {:team_removed, team})
        {:reply, {:ok, team}, %{data | teams: teams}}
    end
  end

  @impl GenServer
  def handle_call({:assign_player, player_id, team_id}, _from, data) do
    %{player_team_map: player_team_map} = data

    player_team_map |> Map.put(player_id, team_id)
    PubSub.broadcast(OpticRed.PubSub, data.room_topic, {:player_assigned, player_id, team_id})
    {:reply, :ok, %{data | player_team_map: player_team_map}}
  end

  @impl GenServer
  def handle_call({:create_new_game, target_score}, _from, data) do
    %{games: games, players: players, teams: teams, player_team_map: player_team_map} = data

    game_state = OpticRed.Game.State.create_new(teams, players, player_team_map, target_score)
    games = [game_state | games]
    PubSub.broadcast(OpticRed.PubSub, data.room_topic, {:game_created, game_state})
    {:reply, {:ok, game_state}, %{data | games: games}}
  end

  @impl GenServer
  def handle_call({:has_joined, player_id}, _from, %{players: players} = data) do
    case Enum.find(players, nil, fn player -> elem(player, 0) == player_id end) do
      nil ->
        {:reply, false, data}

      _ ->
        {:reply, true, data}
    end
  end

  ##
  ## Retrieving
  ##

  @impl GenServer
  def handle_call(:get_current_game, _from, %{games: games} = data) do
    case games do
      [current_game | _] -> {:reply, {:ok, current_game}, data}
      _ -> {:reply, {:error, :no_game_created}, data}
    end
  end

  @impl GenServer
  def handle_call(:get_players, _from, %{players: players} = data) do
    {:reply, {:ok, players}, data}
  end

  @impl GenServer
  def handle_call(:get_teams, _from, %{teams: teams} = data) do
    {:reply, {:ok, teams}, data}
  end

  @impl GenServer
  def handle_call(:get_player_team_map, _from, %{player_team_map: player_team_map} = data) do
    {:reply, {:ok, player_team_map}, data}
  end

  ##
  ## Private
  ##

  defp get_room_name(room_id) do
    {:n, :l, {:room, room_id}}
  end
end
