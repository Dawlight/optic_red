defmodule OpticRed.GameState do
  @behaviour :gen_statem

  require Logger

  ##
  ## API
  ##

  def start_link(%{game_id: game_id, teams: teams}) do
    initial_lead_team = List.first(teams)
    score = Map.new(Enum.map(teams, fn team -> {team, 0} end))

    args = %{
      initial_data: %{
        rounds: [],
        teams: teams,
        lead_team: initial_lead_team,
        score: score
      }
    }

    name = get_game_id_name(game_id)
    :gen_statem.start_link({:via, :gproc, name}, __MODULE__, args, [])
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

  def get_game_state(game_id) do
    case :gproc.where(get_game_id_name(game_id)) do
      :underfined -> {:error, :game_not_found}
      pid -> :gen_statem.call(pid, {:get_game_state})
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

  @impl :gen_statem
  def init(%{initial_data: initial_data}) do
    {:ok, :encipher, initial_data}
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
        :encipher,
        %{rounds: rounds, teams: teams} = data
      ) do
    Logger.debug("Team #{team} submitted clues: #{clues}")
    IO.inspect("Team #{team} submitted clues: #{clues}")
    [current_round | _] = rounds
    current_round = put_in(current_round[team].clues, clues)
    data = update_in(data.rounds, &List.replace_at(&1, 0, current_round))

    reply = {:reply, from, {:ok, data}}

    if Enum.any?(teams, fn team -> current_round[team].clues == nil end) do
      Logger.debug("Not all teams have submtited their clues for this round!")
      IO.inspect("Not all teams have submtited their clues for this round!")
      {:keep_state, data, reply}
    else
      Logger.debug("All teams have submitted their clues for this round!")
      IO.inspect("All teams have submitted their clues for this round!")

      # All teams have submitted clues for the current round
      {:next_state, :decipher, data, reply}
    end
  end

  # DECPIPHER PHASE

  defp do_submit_attempt(%{rounds: rounds, lead_team: lead_team} = data, team, attempt) do
    [current_round | _] = rounds
    current_round = put_in(current_round[team].attempts[lead_team], attempt)
    data = update_in(data.rounds, &List.replace_at(&1, 0, current_round))
  end

  @impl :gen_statem
  def handle_event(
        {:call, from},
        {:submit_attempt, team, attempt},
        :decipher,
        data
      ) do
    data = do_submit_attempt(data, team, attempt)
    [current_round | _] = data.rounds

    all_submitted_attempts =
      Enum.map(current_round, fn {team, _} -> current_round[team].attempts[data.lead_team] end)

    have_all_teams_submitted? = nil not in all_submitted_attempts

    case have_all_teams_submitted? do
      false ->
        IO.inspect("Not all teams have submitted their attempts!")
        Logger.debug("Not all teams have submitted their attempt!")
        {:keep_state, data, {:reply, from, {:ok, data}}}

      true ->
        # Set new lead team
        {next_lead_team, next_lead_team_index} = get_next_lead_team(data.teams, data.lead_team)
        data = put_in(data.lead_team, next_lead_team)

        case next_lead_team_index do
          # Next lead team is the starting lead team. End of phase!
          0 ->
            Logger.debug("That's all! Next!")
            IO.inspect("That's all! Next!")

            round_score = get_round_score(data.teams, current_round)

            total_score = Map.merge(data.score, round_score, fn _, x, y -> x + y end)

            data = put_in(data.score, total_score)

            has_any_team_won? = Enum.any?(Map.values(data.score), fn score -> score >= 1 end)

            case has_any_team_won? do
              true ->
                IO.inspect("Game end!")
                {:next_state, :game_end, data, {:reply, from, {:ok, data}}}

              false ->
                IO.inspect("New round")
                {:next_state, :encipher, data, {:reply, from, {:ok, data}}}
            end

          _ ->
            # Next lead team is just some team. New decipher round!
            Logger.debug("It's time to decipher #{next_lead_team}'s code")
            IO.inspect("It's time to decipher #{next_lead_team}'s code")
            {:next_state, :decipher, data, {:reply, from, {:ok, data}}}
        end
    end
  end

  @impl :gen_statem
  def handle_event({:call, from}, {:get_game_state}, _, data) do
    {:keep_state_and_data, {:reply, from, {:ok, data}}}
  end

  @impl :gen_statem
  def handle_event({:call, from}, {:get_current_round}, _, data) do
    {:keep_state_and_data, {:reply, from, {:ok, List.first(data.rounds)}}}
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

  defp get_next_lead_team(teams, current_lead_team) do
    current_lead_team = Enum.find_index(teams, fn team -> current_lead_team === team end)
    next_lead_team_index = rem(current_lead_team + 1, length(teams))
    next_lead_team = Enum.at(teams, next_lead_team_index)
    {next_lead_team, next_lead_team_index}
  end

  # GAME END

  ##
  ## Private functions
  ##

  defp create_empty_round(teams) do
    Enum.reduce(teams, %{}, fn team, team_map ->
      Map.put(team_map, team, create_team_map(teams))
    end)
  end

  defp create_team_map(teams) do
    %{code: Enum.take_random(1..4, 3), clues: nil, attempts: create_attempts_map(teams)}
  end

  defp create_attempts_map(teams) do
    teams |> Enum.reduce(%{}, fn team, team_map -> Map.put(team_map, team, nil) end)
  end

  def get_game_id_name(game_id) do
    {:n, :l, {:game_id, game_id}}
  end

  def get_random_code() do
    Enum.take_random(1..4, 3)
  end
end
