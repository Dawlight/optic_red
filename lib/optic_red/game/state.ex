defmodule OpticRed.Game.State do
  require Logger

  alias OpticRed.Game.State.Data

  @words ~w{cat tractor house tree love luck money table floor christmas orange}

  ###
  ### Public
  ###
  def create_new(teams, target_score \\ 2) do
    initial_lead_team = List.first(teams)
    score = Map.new(Enum.map(teams, fn team -> {team, 0} end))
    words = create_team_words(teams)

    %{
      current: :setup,
      data: %Data{
        rounds: [],
        teams: teams,
        lead_team: initial_lead_team,
        players: %{},
        score: score,
        words: words,
        target_score: target_score
      }
    }
  end

  def set_player(%{data: %Data{} = data} = state, player_id, team) do
    case state.current do
      :setup ->
        players = Map.put(data.players, player_id, team)

        %{state | data: %{data | players: players}}

      _ ->
        {:error, "Can only assign players during setup phase"}
    end
  end

  def new_round(%{data: %Data{} = data, current: current} = state) do
    case are_there_enough_players?(state) do
      true ->
        if current in [:setup, :round_end] do
          new_round = create_empty_round(data.teams)
          data = update_in(data.rounds, fn rounds -> [new_round | rounds] end)
          %{state | data: data, current: :encipher}
        else
          {:error, "Can't start new round in the middle of an ongoing round"}
        end

      false ->
        {:error, "Can't start new round without at least two players in each team"}
    end
  end

  def submit_clues(
        %{data: %Data{rounds: rounds, teams: teams} = data, current: current} = state,
        team,
        clues
      ) do
    case current do
      :encipher ->
        [current_round | _] = rounds
        current_round = put_in(current_round[team].clues, clues)
        data = update_in(data.rounds, &List.replace_at(&1, 0, current_round))

        if Enum.any?(teams, fn team -> current_round[team].clues == nil end) do
          %{state | data: data}
        else
          %{state | data: data, current: :decipher}
        end

      _ ->
        {:error, "Subbmitting clues only allowed during encipher phase"}
    end
  end

  def submit_attempt(%{data: %Data{} = data} = state, team, attempt) do
    IO.inspect(nil, label: "Team #{team} submitts attempt #{attempt}")
    data = do_submit_attempt(data, team, attempt)

    case have_all_teams_submitted?(data) |> IO.inspect(label: "All teams have submitted?") do
      false ->
        %{state | data: data}

      # {:keep_state, data, {:reply, from, {:ok, state, data}}}

      true ->
        next_lead_team = get_next_lead_team(data)

        case have_all_teams_been_lead?(data) do
          true ->
            data = update_score(data)

            case has_any_team_won?(data) do
              true ->
                data = %{data | lead_team: next_lead_team}
                %{state | data: data, current: :game_end}

              # {:next_state, :game_end, data, {:reply, from, {:ok, state, data}}}

              false ->
                data = %{data | lead_team: next_lead_team}
                %{state | data: data, current: :encipher}

                # {:next_state, :encipher, data, {:reply, from, {:ok, state, data}}}
            end

          false ->
            data = %{data | lead_team: next_lead_team}
            %{state | data: data, current: :decipher}

            # {:next_state, :decipher, data, {:reply, from, {:ok, state, data}}}
        end
    end
  end

  ###
  ### Private
  ###

  defp are_there_enough_players?(state) do
    Enum.all?(get_team_players_map(state), fn {_, players} -> length(players) >= 2 end)
  end

  defp get_team_players_map(%{data: %Data{players: players}}) do
    Enum.group_by(players, fn {_, team} -> team end, fn {player_id, _} -> player_id end)
  end

  defp do_submit_attempt(%Data{rounds: rounds, lead_team: lead_team} = data, team, attempt) do
    [current_round | _] = rounds
    current_round = put_in(current_round[team].attempts[lead_team], attempt)
    update_in(data.rounds, &List.replace_at(&1, 0, current_round))
  end

  defp have_all_teams_submitted?(%Data{} = data) do
    [current_round | _] = data.rounds

    all_submitted_attempts =
      Enum.map(current_round, fn {team, _} -> current_round[team].attempts[data.lead_team] end)
      |> IO.inspect(label: "All submitted attempts")

    nil not in all_submitted_attempts
  end

  defp have_all_teams_been_lead?(%Data{} = data) do
    next_lead_team = get_next_lead_team(data)
    first_lead_team = List.first(data.teams)
    next_lead_team == first_lead_team
  end

  defp update_score(%Data{} = data) do
    [current_round | _] = data.rounds
    round_score = get_round_score(data.teams, current_round)
    total_score = Map.merge(data.score, round_score, fn _, x, y -> x + y end)
    put_in(data.score, total_score)
  end

  defp has_any_team_won?(%Data{target_score: target_score} = data) do
    Enum.any?(Map.values(data.score), fn score -> score >= target_score end)
  end

  defp get_round_score(teams, round) do
    matchups =
      for deciphering_team <- teams,
          enciphering_team <- teams,
          do: {deciphering_team, enciphering_team}

    Enum.reduce(matchups, %{}, fn {dec_team, enc_team}, score_totals ->
      score = get_team_vs_team_round_score(dec_team, enc_team, round)
      Map.update(score_totals, dec_team, score, fn current_score -> current_score + score end)
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

  defp get_next_lead_team(%Data{} = data) do
    lead_team_index = Enum.find_index(data.teams, fn team -> team == data.lead_team end)
    next_lead_team_index = rem(lead_team_index + 1, length(data.teams))
    Enum.at(data.teams, next_lead_team_index)
  end

  defp create_empty_round(teams) do
    Enum.reduce(teams, %{}, fn team, team_map ->
      Map.put(team_map, team, create_team_map(teams))
    end)
  end

  defp create_team_map(teams) do
    %{
      code: Enum.take_random(1..4, 3),
      clues: nil,
      attempts: create_attempts_map(teams)
    }
  end

  defp create_attempts_map(teams) do
    teams |> Enum.reduce(%{}, fn team, team_map -> Map.put(team_map, team, nil) end)
  end

  def get_game_id_name(game_id) do
    {:n, :l, {:game_state, game_id}}
  end

  def get_random_code() do
    Enum.take_random(1..4, 3)
  end

  defp create_team_words(teams) do
    words = Enum.shuffle(@words)
    word_lists = Enum.chunk_every(words, 4)
    Map.new(Enum.zip([teams, word_lists]))
  end
end
