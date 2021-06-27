defmodule OpticRed.Game do
  use GenServer
  require Logger

  alias OpticRed.Game.State
  alias Phoenix.PubSub

  ##
  ## API
  ##

  def start_link(%{room_id: room_id} = args) do
    name = get_game_name(room_id)
    GenServer.start_link(__MODULE__, args, name: {:via, :gproc, name})
  end

  def get_state(room_id) do
    case :gproc.where(get_game_name(room_id)) do
      :undefined -> {:error, :game_not_found}
      pid -> GenServer.call(pid, :get_state)
    end
  end

  def join_game(room_id, player_id, team) do
    case :gproc.where(get_game_name(room_id)) do
      :undefined -> {:error, :game_not_found}
      pid -> GenServer.call(pid, {:join_game, player_id, team})
    end
  end

  def leave_game(room_id, player_id) do
    case :gproc.where(get_game_name(room_id)) do
      :undefined -> {:error, :game_not_found}
      pid -> GenServer.call(pid, {:leave_game, player_id})
    end
  end

  ##
  ## CALLBACKS
  ##

  @impl GenServer
  def init(%{room_id: room_id, teams: teams}) do
    state = State.create_new(teams) |> IO.inspect(label: "NEW GAME DESU!")

    {:ok,
     %{
       room_id: room_id,
       state: state,
       game_topic: "room:#{room_id}:game"
     }}
  end

  @impl GenServer
  def handle_call({:join_game, player_id, team}, _from, %{state: state} = data) do
    state =
      state
      |> State.set_player(player_id, team)

    PubSub.broadcast(OpticRed.PubSub, data.game_topic, {:game_state_updated, state})

    {:reply, :ok, %{data | state: state}}
  end

  @impl GenServer
  def handle_call({:leave_game, player_id}, _from, %{state: state} = data) do
    state =
      state
      |> State.remove_player(player_id)

    PubSub.broadcast(OpticRed.PubSub, data.game_topic, {:game_state_updated, state})

    {:reply, :ok, %{data | state: state}}
  end

  @impl GenServer
  def handle_call(:get_state, _from, %{state: state} = data) do
    {:reply, {:ok, state}, data}
  end

  ##
  ## Private
  ##

  defp get_game_name(room_id) do
    {:n, :l, {:game, room_id}}
  end
end
