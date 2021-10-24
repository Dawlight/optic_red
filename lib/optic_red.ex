defmodule OpticRed do
  @moduledoc """
  Interaction with room and games
  """

  alias OpticRed.Game.State.Player
  alias OpticRed.Game.State.Team
  alias OpticRed.Game.State.State

  @type player_team_map :: %{
          binary() => binary()
        }

  @doc """
  Creates new room

  Returns: {:ok, room_id}
  """
  @spec create_new_room() :: {:ok, binary()}
  def create_new_room() do
    room_id = :crypto.strong_rand_bytes(4) |> Base.url_encode64(padding: false)
    {:ok, _pid} = OpticRed.Lobby.Supervisor.create_room(room_id)

    {:ok, room_id}
  end

  @doc """
  Adds player to room

  Returns: {:ok, player}
  """
  @spec add_player(binary(), binary(), binary()) :: {:ok, Player.t()}
  def add_player(room_id, player_id, name) do
    OpticRed.Room.add_player(room_id, player_id, name)
  end

  @doc """
  Removes player from room

  Returns: {:ok, player}
  """
  @spec remove_player(binary(), binary()) :: {:ok, Player.t()}
  def remove_player(room_id, player_id) do
    OpticRed.Room.remove_player(room_id, player_id)
  end

  @doc """
  Adds team to room

  Returns: {:ok, team}
  """
  @spec add_team(binary(), binary(), binary()) :: {:ok, Player.t()}
  def add_team(room_id, team_id, name) do
    OpticRed.Room.add_team(room_id, team_id, name)
  end

  @doc """
  Removes team from room

  Returns: {:ok, team}
  """
  @spec remove_team(binary(), binary()) :: {:ok, Team.t()}
  def remove_team(room_id, team_id) do
    OpticRed.Room.remove_team(room_id, team_id)
  end

  @doc """
  Assigns player to team

  Returns: :ok
  """
  @spec assign_player(binary(), binary(), binary()) :: :ok
  def assign_player(room_id, player_id, team_id) do
    OpticRed.Room.assign_player(room_id, player_id, team_id)
  end

  @doc """
  Check whether room exists or not

  Returns: true | false
  """
  @spec room_exists?(binary()) :: true | false
  def room_exists?(room_id) do
    OpticRed.Room.exists?(room_id)
  end

  @doc """
  Creates new game

  Creating a new game will replace an active game in progress. Try not to use during an on-going game.

  Returns: {:ok, game_state}
  """
  @spec create_new_game(binary(), integer()) :: {:ok, State.t()}
  def create_new_game(room_id, target_score) do
    OpticRed.Room.create_new_game(room_id, target_score)
  end

  def set_player_ready(room_id, player_id, ready?) do
    OpticRed.Room.set_player_ready(room_id, player_id, ready?)
  end

  def submit_clues(room_id, team_id, clues) do
    OpticRed.Room.submit_clues(room_id, team_id, clues)
  end

  def submit_attempt(room_id, team_id, attempt_numbers) do
    OpticRed.Room.submit_attempt(room_id, team_id, attempt_numbers)
  end

  @doc """
  Get current game state

  Returns: {:ok, game_state}
  """
  @spec get_game_state(binary()) :: {:ok, State.t()}
  def get_game_state(room_id) do
    OpticRed.Room.get_current_game(room_id)
  end

  @doc """
  Get players

  Returns: {:ok, players}
  """
  @spec get_players(binary()) :: {:ok, [Player.t()]}
  def get_players(room_id) do
    OpticRed.Room.get_players(room_id)
  end

  @doc """
  Get teams

  Returns: {:ok, teams}
  """
  @spec get_teams(binary()) :: {:ok, [Team.t()]}
  def get_teams(room_id) do
    OpticRed.Room.get_teams(room_id)
  end

  @doc """
  Get map mapping from player id to team id

  Returns: {:ok, player_team_map}
  """
  @spec get_player_team_map(binary()) :: {:ok, player_team_map}
  def get_player_team_map(room_id) do
    OpticRed.Room.get_player_team_map(room_id)
  end
end
