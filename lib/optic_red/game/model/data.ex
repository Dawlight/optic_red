defmodule OpticRed.Game.Model.Data do
  defstruct [
    :target_points,
    teams: [],
    players: [],
    rounds: [],
    words_by_team_id: %{},
    points_by_team_id: %{},
    strikes_by_team_id: %{},
    encipherer_pool_by_team_id: %{}
  ]

  use OpticRed.Game.Model

  alias OpticRed.Game.Model.{
    Team,
    Player,
    Round
  }

  ##
  ## Transform
  ##

  def add_team(%__MODULE__{teams: teams} = data, %Team{} = new_team) do
    teams = [new_team | teams] |> Enum.uniq_by(fn %Team{id: id} -> id end)
    data |> where(teams: teams)
  end

  def remove_team(%__MODULE__{} = data, %Team{id: team_id}) do
    data |> remove_team_by_id(team_id)
  end

  def remove_team_by_id(%__MODULE__{teams: teams} = data, team_id) do
    teams = teams |> Enum.filter(fn team -> team.id != team_id end)
    data |> where(teams: teams)
  end

  def add_player(%__MODULE__{players: players} = data, %Player{} = new_player) do
    players = [new_player | players] |> Enum.uniq_by(fn %Player{id: id} -> id end)
    data |> where(players: players)
  end

  def remove_player(%__MODULE__{} = data, %Player{id: player_id}) do
    data |> remove_player_by_id(player_id)
  end

  def remove_player_by_id(%__MODULE__{players: players} = data, player_id) do
    players = players |> Enum.filter(fn player -> player.id != player_id end)
    data |> where(players: players)
  end

  def set_player_team(%__MODULE__{} = data, %Player{} = player, nil) do
    set_player_team(data, player, %Team{id: nil})
  end

  def set_player_team(%__MODULE__{players: players} = data, %Player{id: player_id}, %Team{
        id: team_id
      }) do
    players =
      players
      |> Enum.map(fn player ->
        case player.id do
          ^player_id -> player |> Player.where(team_id: team_id)
          _ -> player
        end
      end)

    data |> where(players: players)
  end

  def add_round(%__MODULE__{rounds: rounds} = data, %Round{} = round) do
    data |> where(rounds: [round | rounds])
  end

  def update_round(%__MODULE__{rounds: rounds} = data, index, update_function) do
    rounds = rounds |> List.update_at(index, update_function)
    data |> where(rounds: rounds)
  end

  def set_target_points(%__MODULE__{} = data, target_points) do
    data |> where(target_points: target_points)
  end

  def set_team_words(%__MODULE__{words_by_team_id: words_by_team_id} = data, team, words) do
    words_by_team_id = words_by_team_id |> Map.put(team.id, words)
    data |> where(words_by_team_id: words_by_team_id)
  end

  def set_team_points(%__MODULE__{points_by_team_id: points_by_team_id} = data, team, points) do
    points_by_team_id = points_by_team_id |> Map.put(team.id, points)
    data |> where(points_by_team_id: points_by_team_id)
  end

  def set_team_strikes(%__MODULE__{strikes_by_team_id: strikes_by_team_id} = data, team, strikes) do
    strikes_by_team_id = strikes_by_team_id |> Map.put(team.id, strikes)
    data |> where(strikes_by_team_id: strikes_by_team_id)
  end

  def pop_random_encipherer(%__MODULE__{} = data, %Team{} = team) do
    %__MODULE__{encipherer_pool_by_team_id: encipherer_pools} = data

    case encipherer_pools[team.id] do
      pool when is_list(pool) and pool != [] ->
        encipherer = pool |> Enum.random()
        pool = pool |> List.delete(encipherer)
        encipherer_pools = encipherer_pools |> Map.put(team.id, pool)
        {encipherer, data |> where(encipherer_pool_by_team_id: encipherer_pools)}

      _ ->
        data
        |> refill_encipherer_pool(team)
        |> pop_random_encipherer(team)
    end
  end

  def refill_encipherer_pool(%__MODULE__{} = data, team) do
    %__MODULE__{encipherer_pool_by_team_id: encipherer_pools} = data

    players = data |> Data.get_players_by_team(team)
    encipherer_pools = encipherer_pools |> Map.put(team.id, players)

    data |> where(encipherer_pool_by_team_id: encipherer_pools)
  end

  ##
  ## Access
  ##

  def get_teams_that_lost(%__MODULE__{} = data) do
    %__MODULE__{
      teams: teams,
      strikes_by_team_id: strikes_by_team_id,
      target_points: target_points
    } = data

    teams |> Enum.filter(fn team -> strikes_by_team_id[team.id] >= target_points end)
  end

  def get_teams_that_won(%__MODULE__{} = data) do
    %__MODULE__{
      teams: teams,
      points_by_team_id: points_by_team_id,
      target_points: target_points
    } = data

    teams |> Enum.filter(fn team -> points_by_team_id[team.id] >= target_points end)
  end

  def get_remaining_teams(%__MODULE__{} = data) do
    %__MODULE__{
      teams: teams,
      strikes_by_team_id: strikes_by_team_id,
      target_points: target_points
    } = data

    teams |> Enum.filter(fn team -> strikes_by_team_id[team.id] < target_points end)
  end

  def get_team_by_id(%__MODULE__{teams: teams}, team_id) do
    teams |> Enum.find(fn team -> team.id == team_id end)
  end

  def get_player_by_id(%__MODULE__{players: players}, player_id) do
    players |> Enum.find(fn player -> player.id == player_id end)
  end

  def get_players_by_team_id(%__MODULE__{players: players}, team_id) do
    players |> Enum.filter(fn player -> player.team_id == team_id end)
  end

  def get_players_by_team(%__MODULE__{} = data, %Team{id: team_id}) do
    data |> get_players_by_team_id(team_id)
  end

  def get_team_by_player_id(%__MODULE__{teams: teams} = data, player_id) do
    player = data |> get_player_by_id(player_id)
    teams |> Enum.find(fn team -> team.id == player.team_id end)
  end

  def get_team_by_player(%__MODULE__{} = data, %Player{id: player_id}) do
    data |> get_team_by_player_id(player_id)
  end

  def get_round(%__MODULE__{rounds: rounds}, index) do
    rounds |> Enum.at(index, nil)
  end

  def get_words(%__MODULE__{words_by_team_id: words_by_team_id}, %Team{id: team_id}) do
    words_by_team_id[team_id]
  end

  def get_points(%__MODULE__{points_by_team_id: points_by_team_id}, %Team{id: team_id}) do
    points_by_team_id[team_id]
  end

  def get_strikes(%__MODULE__{strikes_by_team_id: strikes_by_team_id}, %Team{id: team_id}) do
    strikes_by_team_id[team_id]
  end

  #
  # Private
  #
end
