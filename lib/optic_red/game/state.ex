defmodule OpticRed.Game.State do
  defstruct [:data, :current]

  require Logger

  alias OpticRed.Game.State.Data
  alias OpticRed.Game.State.Team
  alias OpticRed.Game.State.Player
  alias OpticRed.Game.State.TeamRound

  @words ~w{cat tractor house tree love luck money table floor christmas orange}

  ###
  ### Public
  ###

  def create_new(teams, players, player_team_map, target_score \\ 2) do
    case teams do
      teams when length(teams) < 2 ->
        [initial_lead_team | _rest] = teams
        team_words_map = create_team_words_map(teams)

        player_map = for %Player{id: id} = player <- players, into: %{}, do: {id, player}
        team_map = for %Team{id: id} = team <- teams, into: %{}, do: {id, team}
        team_score_map = for %Team{id: id} <- teams, into: %{}, do: {id, 0}

        %__MODULE__{
          current: :setup,
          data: %Data{
            rounds: [],
            teams: teams,
            team_map: team_map,
            player_map: player_map,
            player_team_map: player_team_map,
            lead_team_id: initial_lead_team.id,
            team_words_map: team_words_map,
            target_score: target_score,
            team_score_map: team_score_map
          }
        }

      _ ->
        {:error, :insufficient_number_of_teams}
    end
  end

  def new_round(%__MODULE__{data: data, current: current} = state) do
    %Data{rounds: rounds} = data

    case minimum_number_of_players?(state) do
      true ->
        if current in [:setup, :round_end] do
          rounds = [create_new_round(data) | rounds]

          %{state | data: %{data | rounds: rounds}, current: :encipher}
        else
          {:error, "Can't start new round in the middle of an ongoing round"}
        end

      false ->
        {:error, "Can't start new round without at least two players in each team"}
    end
  end

  ## TODO: FINISH WHERE I LEFT OFF

  ##
  ## Encipher
  ##

  def submit_clues(%__MODULE__{current: current}, _team_id, _clues) when current != :encipher do
    {:error, "Subbmitting clues only allowed during encipher phase"}
  end

  def submit_clues(%__MODULE__{} = state, team_id, clues) do
    %__MODULE__{data: %Data{rounds: rounds, team_map: team_map} = data} = state
    [current_round | _] = rounds
    current_round = put_in(current_round[team_id].clues, clues)
    data = update_in(data.rounds, &List.replace_at(&1, 0, current_round))

    if Enum.any?(team_map, fn {team_id, _} -> current_round[team_id].clues == nil end) do
      %{state | data: data}
    else
      %{state | data: data, current: :decipher}
    end
  end

  ##
  ## Decipher
  ##

  def submit_attempt(%__MODULE__{current: current}, _team, _attempt) when current != :decipher do
    {:error, "Submitting attempts only allowed during decipher phase"}
  end

  def submit_attempt(%__MODULE__{data: %Data{} = data} = state, team_id, attempt) do
    attempt |> IO.inspect(label: "Team #{team_id} submits attempt")
    data = data |> do_submit_attempt(team_id, attempt)

    case have_all_teams_submitted?(data) |> IO.inspect(label: "All teams have submitted?") do
      false ->
        %{state | data: data}

      # {:keep_state, data, {:reply, from, {:ok, state, data}}}

      true ->
        next_lead_team = get_next_lead_team(data)

        case have_all_teams_been_lead?(data) |> IO.inspect(label: "All teams have been lead?") do
          true ->
            data = update_score(data)

            case has_any_team_won?(data) do
              true ->
                data = %Data{data | lead_team_id: next_lead_team.id}
                %__MODULE__{state | data: data, current: :game_end}

              # {:next_state, :game_end, data, {:reply, from, {:ok, state, data}}}

              false ->
                data = %Data{data | lead_team_id: next_lead_team.id}
                %__MODULE__{state | data: data, current: :encipher}

                # {:next_state, :encipher, data, {:reply, from, {:ok, state, data}}}
            end

          false ->
            data = %Data{data | lead_team_id: next_lead_team.id}
            %__MODULE__{state | data: data, current: :decipher}

            # {:next_state, :decipher, data, {:reply, from, {:ok, state, data}}}
        end
    end
  end

  ###
  ### Getters
  ###

  def get_players_by_team_id(data, team_id) do
    %Data{player_team_map: player_team_map, player_map: player_map} = data

    player_ids =
      player_team_map
      |> Enum.filter(fn {_, player_team_id} -> player_team_id == team_id end)
      |> Enum.map(&elem(&1, 0))

    player_map
    |> Map.take(player_ids)
    |> Enum.map(fn {_, player} -> player end)
  end

  ###
  ### Private
  ###

  defp minimum_number_of_players?(%{data: %Data{team_map: team_map}} = state) do
    Enum.all?(team_map, fn {team_id, _team} -> get_player_count(state, team_id) >= 2 end)
  end

  defp get_player_count(%{data: %Data{player_team_map: player_team_map}}, team_id_to_count) do
    Enum.count(player_team_map, fn {_player_id, team_id} -> team_id == team_id_to_count end)
  end

  defp do_submit_attempt(data, team_id, attempt) do
    %Data{rounds: rounds, lead_team_id: lead_team_id} = data
    [current_round | _] = rounds
    current_round = put_in(current_round[team_id].attempts[lead_team_id], attempt)
    update_in(data.rounds, &List.replace_at(&1, 0, current_round))
  end

  defp have_all_teams_submitted?(%Data{} = data) do
    [current_round | _] = data.rounds

    current_round |> IO.inspect(label: "CURRENT ROUND")

    all_submitted_attempts =
      Enum.map(current_round, fn {team, _} -> current_round[team].attempts[data.lead_team_id] end)

    nil not in all_submitted_attempts
  end

  defp have_all_teams_been_lead?(%Data{teams: teams} = data) do
    next_lead_team = get_next_lead_team(data)
    next_lead_team_index = teams |> Enum.find_index(&(&1.id == next_lead_team.id))
    next_lead_team_index == 0
  end

  defp update_score(data) do
    %Data{rounds: rounds, team_map: team_map, team_score_map: team_score_map} = data
    [current_round | _] = rounds
    round_score = get_round_score(team_map, current_round)
    total_score = Map.merge(team_score_map, round_score, fn _, x, y -> x + y end)
    put_in(data.team_score_map, total_score)
  end

  defp has_any_team_won?(%Data{target_score: target_score} = data) do
    Enum.any?(Map.values(data.team_score_map), fn score -> score >= target_score end)
  end

  defp get_round_score(team_map, round) do
    matchups =
      for {deciphering_team_id, _} <- team_map,
          {enciphering_team_id, _} <- team_map,
          do: {deciphering_team_id, enciphering_team_id}

    Enum.reduce(matchups, %{}, fn {dec_team_id, enc_team_id}, score_totals ->
      score = get_team_vs_team_round_score(dec_team_id, enc_team_id, round)
      Map.update(score_totals, dec_team_id, score, fn current_score -> current_score + score end)
    end)
  end

  defp get_team_vs_team_round_score(desciphering_team, enciperhing_team, round) do
    attempt = round[desciphering_team].attempts[enciperhing_team]
    code = round[enciperhing_team].code

    cond do
      # Bad attempt at own team's code
      attempt != code and enciperhing_team === desciphering_team -> -2
      # Good attempt at opposing team's code
      attempt === code and enciperhing_team !== desciphering_team -> 1
      # Otherwise no points
      true -> 0
    end
  end

  defp get_next_lead_team(%Data{teams: teams, lead_team_id: lead_team_id}) do
    lead_team_index = teams |> Enum.find_index(&(&1.id == lead_team_id))
    next_lead_team_index = rem(lead_team_index + 1, length(teams))
    {:ok, next_lead_team} = teams |> Enum.fetch(next_lead_team_index)
    next_lead_team
  end

  defp create_new_round(%Data{team_map: team_map} = data),
    do: for({id, _} <- team_map, into: %{}, do: {id, create_team_round(id, data)})

  defp create_team_round(team_id, %Data{} = data),
    do: %TeamRound{
      encipherer_player_id: Enum.random(get_players_by_team_id(data, team_id)).id,
      code: get_random_code(),
      clues: nil,
      attempts: create_attempts_map(data)
    }

  defp create_attempts_map(%Data{team_map: team_map}),
    do: for({id, _} <- team_map, into: %{}, do: {id, nil})

  def get_random_code(), do: Enum.take_random(1..4, 3)

  defp create_team_words_map(teams) do
    words = Enum.shuffle(@words)
    word_lists = Enum.chunk_every(words, 4)
    team_ids = teams |> Enum.map(& &1.id)
    Map.new(Enum.zip([team_ids, word_lists]))
  end

  def get_game_id_name(game_id), do: {:n, :l, {:game_state, game_id}}
end
