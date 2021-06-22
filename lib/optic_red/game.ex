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

  def join_game(room_id, player_id, team) do
    case :gproc.where(get_game_name(room_id)) do
      :undefined -> false
      pid -> GenServer.call(pid, {:join_game, player_id, team})
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

    PubSub.broadcast(OpticRed.PubSub, data.game_topic, {:player_joined_team, player_id, team})

    {:reply, :ok, %{data | state: state}}
  end

  ##
  ## Private
  ##

  defp get_game_name(room_id) do
    {:n, :l, {:game, room_id}}
  end
end
