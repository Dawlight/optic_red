defmodule OpticRed.Game.Coordinator do
  @behaviour :gen_statem

  require Logger

  ##
  ## API
  ##

  def start_link(%{game_id: game_id, teams: teams}) do
    initial_lead_team = List.first(teams)
    score = Map.new(Enum.map(teams, fn team -> {team, 0} end))
    words = create_team_words(teams)

    args = %{
      initial_data: %{
        rounds: [],
        teams: teams,
        lead_team: initial_lead_team,
        players: Map.new(Enum.map(teams, fn team -> {team, []} end)),
        score: score,
        words: words
      }
    }

    name = get_game_id_name(game_id)
    :gen_statem.start_link({:via, :gproc, name}, __MODULE__, args, [])
  end

  def set_player(game_id, player_id, team) do
    case :gproc.where(get_game_id_name(game_id)) do
      :undefined -> {:error, :game_not_found}
      pid -> :gen_statem.call(pid, {:set_player, player_id, team})
    end
  end

  def start_game(game_id) do
    case :gproc.where(get_game_id_name(game_id)) do
      :undefined -> {:error, :game_not_found}
      pid -> :gen_statem.call(pid, :start_game)
    end
  end

  def submit_clues(game_id, team, clues) do
    case :gproc.where(get_game_id_name(game_id)) do
      :undefined -> {:error, :game_not_found}
      pid -> :gen_statem.call(pid, {:submit_clues, team, clues})
    end
  end

  def submit_attempt(game_id, team, attempt) do
    case :gproc.where(get_game_id_name(game_id)) do
      :undefined -> {:error, :game_not_found}
      pid -> :gen_statem.call(pid, {:submit_attempt, team, attempt})
    end
  end

  def get_game_data(game_id) do
    case :gproc.where(get_game_id_name(game_id)) do
      :underfined -> {:error, :game_not_found}
      pid -> :gen_statem.call(pid, {:get_game_data})
    end
  end

  def get_current_state(game_id) do
    case :gproc.where(get_game_id_name(game_id)) do
      :underfined -> {:error, :game_not_found}
      pid -> :gen_statem.call(pid, {:get_current_state})
    end
  end

  def get_current_round(game_id) do
    case :gproc.where(get_game_id_name(game_id)) do
      :underfined -> {:error, :game_not_found}
      pid -> :gen_statem.call(pid, {:get_current_round})
    end
  end

  ##
  ## CALLBACKS
  ##

  def child_spec(options) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [options]}
    }
  end

  @impl :gen_statem
  def init(%{initial_data: initial_data}) do
    {:ok, :standby, initial_data}
  end

  @impl :gen_statem
  def callback_mode() do
    [:handle_event_function, :state_enter]
  end

  @impl :gen_statem
  def handle_event(:enter, _old_state, :decipher, %{lead_team: lead_team} = _data) do
    Logger.debug("Time to decipher team #{lead_team}'s code!")
    :keep_state_and_data
  end

  # STANDBY

  @impl :gen_statem
  def handle_event({:call, _from}, {:set_player, player_id, team}, :standby, data) do
    team_player_ids = data.players[team]
    team_player_ids = Enum.uniq([player_id | team_player_ids])

    data = put_in(data.players[team], team_player_ids)

    {:keep_state, data}
  end

  @impl :gen_statem
  def handle_event({:call, _from}, :start_game, :standby, data) do
    {:next_state, :encipher, data}
  end

  # ENTER: NEW ROUND

  @impl :gen_statem
  def handle_event(:enter, _, :encipher, data) do
    Logger.debug("New round!")
    new_round = create_empty_round(data.teams)
    data = update_in(data.rounds, fn rounds -> [new_round | rounds] end)

    {:next_state, :encipher, data}
  end

  # ENTER: GAME END

  @impl :gen_statem
  def handle_event(:enter, _, :game_end, data) do
    Logger.debug("Game end.")
    {:next_state, :game_end, data}
  end

  # ENCIPHER

  @impl :gen_statem
  def handle_event(
        {:call, from},
        {:submit_clues, team, clues},
        :encipher = state,
        %{rounds: rounds, teams: teams} = data
      ) do
    [current_round | _] = rounds
    current_round = put_in(current_round[team].clues, clues)
    data = update_in(data.rounds, &List.replace_at(&1, 0, current_round))

    reply = {:reply, from, {:ok, state, data}}

    if Enum.any?(teams, fn team -> current_round[team].clues == nil end) do
      {:keep_state, data, reply}
    else
      {:next_state, :decipher, data, reply}
    end
  end

  # DECPIPHER PHASE

  @impl :gen_statem
  def handle_event(
        {:call, from},
        {:submit_attempt, team, attempt},
        :decipher = state,
        data
      ) do
    data = do_submit_attempt(data, team, attempt)

    case have_all_teams_submitted?(data) do
      false ->
        {:keep_state, data, {:reply, from, {:ok, state, data}}}

      true ->
        next_lead_team = get_next_lead_team(data)

        case have_all_teams_been_lead?(data) do
          true ->
            data = update_score(data)

            case has_any_team_won?(data) do
              true ->
                data = %{data | lead_team: next_lead_team}
                {:next_state, :game_end, data, {:reply, from, {:ok, state, data}}}

              false ->
                data = %{data | lead_team: next_lead_team}
                {:next_state, :encipher, data, {:reply, from, {:ok, state, data}}}
            end

          false ->
            data = %{data | lead_team: next_lead_team}
            {:next_state, :decipher, data, {:reply, from, {:ok, state, data}}}
        end
    end
  end

  @impl :gen_statem
  def handle_event({:call, from}, {:get_game_data}, _, data) do
    {:keep_state_and_data, {:reply, from, {:ok, data}}}
  end

  @impl :gen_statem
  def handle_event({:call, from}, {:get_current_round}, _, data) do
    {:keep_state_and_data, {:reply, from, {:ok, List.first(data.rounds)}}}
  end

  @impl :gen_statem
  def handle_event({:call, from}, {:get_game_state}, state, _data) do
    {:keep_state_and_data, {:reply, from, {:ok, state}}}
  end

  defp do_submit_attempt(%{rounds: rounds, lead_team: lead_team} = data, team, attempt) do
    [current_round | _] = rounds
    current_round = put_in(current_round[team].attempts[lead_team], attempt)
    update_in(data.rounds, &List.replace_at(&1, 0, current_round))
  end

  defp have_all_teams_submitted?(data) do
    [current_round | _] = data.rounds

    all_submitted_attempts =
      Enum.map(current_round, fn {team, _} -> current_round[team].attempts[data.lead_team] end)

    nil not in all_submitted_attempts
  end

  defp have_all_teams_been_lead?(data) do
    next_lead_team = get_next_lead_team(data)
    first_lead_team = List.first(data.teams)
    next_lead_team == first_lead_team
  end

  defp update_score(data) do
    [current_round | _] = data.rounds
    round_score = get_round_score(data.teams, current_round)
    total_score = Map.merge(data.score, round_score, fn _, x, y -> x + y end)
    put_in(data.score, total_score)
  end

  defp has_any_team_won?(data) do
    Enum.any?(Map.values(data.score), fn score -> score >= 1 end)
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

  defp get_next_lead_team(data) do
    lead_team_index = Enum.find_index(data.teams, fn team -> team == data.lead_team end)
    next_lead_team_index = rem(lead_team_index + 1, length(data.teams))
    Enum.at(data.teams, next_lead_team_index)
  end

  # GAME END

  ##
  ## Private functions
  ##

  @words ~w{cat tractor house tree love luck money table floor christmas orange}

  defp create_empty_round(teams) do
    Enum.reduce(teams, %{}, fn team, team_map ->
      Map.put(team_map, team, create_team_map(teams))
    end)
  end

  defp create_team_words(teams) do
    words = Enum.shuffle(@words)
    word_lists = Enum.chunk_every(words, 4)
    Map.new(Enum.zip([teams, word_lists]))
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
end
