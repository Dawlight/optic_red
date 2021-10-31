defmodule OpticRed.Game.State.Round do
  defstruct encipherer_id_by_team_id: %{},
            code_by_team_id: %{},
            clues_by_team_id: %{},
            attempts_by_team_id: %{}

  alias OpticRed.Game.State.Team

  use OpticRed.Game.State.Where

  def from_teams(teams) do
    %__MODULE__{}
    |> with_default_attempts(teams)
    |> with_default_clues(teams)
  end

  # Encipherer

  def get_encipherer_id(%__MODULE__{} = round, team_id) do
    %__MODULE__{encipherer_id_by_team_id: encipherer_id_by_team_id} = round
    encipherer_id_by_team_id[team_id]
  end

  def with_encipherers(%__MODULE__{} = round, encipherer_id_by_team_id) do
    round |> where(encipherer_id_by_team_id: encipherer_id_by_team_id)
  end

  def set_encipherer(%__MODULE__{} = round, team_id, encipherer) do
    %__MODULE__{encipherer_id_by_team_id: encipherer_id_by_team_id} = round
    encipherer_id_by_team_id = encipherer_id_by_team_id |> Map.put(team_id, encipherer)

    round |> where(encipherer_id_by_team_id: encipherer_id_by_team_id)
  end

  # Code

  def get_code(%__MODULE__{code_by_team_id: code_by_team_id}, team_id) do
    code_by_team_id[team_id]
  end

  def set_code(%__MODULE__{code_by_team_id: code_by_team_id} = round, team_id, code) do
    code_by_team_id = code_by_team_id |> Map.put(team_id, code)

    round |> where(code_by_team_id: code_by_team_id)
  end

  def with_codes(%__MODULE__{} = round, code_by_team_id) do
    round |> where(code_by_team_id: code_by_team_id)
  end

  # Clues

  def get_clues(%__MODULE__{clues_by_team_id: clues_by_team_id}, team_id) do
    clues_by_team_id[team_id]
  end

  def set_clues(%__MODULE__{clues_by_team_id: clues_by_team_id} = round, team_id, clues) do
    clues_by_team_id = clues_by_team_id |> Map.put(team_id, clues)

    round |> where(clues_by_team_id: clues_by_team_id)
  end

  def with_default_clues(%__MODULE__{} = round, teams) do
    clues_by_team_id = for %Team{id: id} <- teams, into: %{}, do: {id, nil}

    round |> where(clues_by_team_id: clues_by_team_id)
  end

  # Attempts

  def get_attempt(%__MODULE__{} = round, decipherer_team_id, encipherer_team_id) do
    %__MODULE__{attempts_by_team_id: attempts_by_team_id} = round

    case attempts_by_team_id[decipherer_team_id] do
      %{^encipherer_team_id => attempt} -> attempt
      _ -> nil
    end
  end

  def set_attempt(%__MODULE__{} = round, decipherer_team_id, encipherer_team_id, attempt) do
    %__MODULE__{attempts_by_team_id: attempts_by_team_id} = round

    attempts_by_team_id =
      update_in(attempts_by_team_id[decipherer_team_id], fn attempts ->
        case attempts do
          nil -> %{}
          _ -> attempts
        end
        |> Map.put(encipherer_team_id, attempt)
      end)

    round
    |> where(attempts_by_team_id: attempts_by_team_id)
  end

  def with_default_attempts(%__MODULE__{} = round, teams) do
    attempts_by_team_id =
      for %Team{id: current_team_id} <- teams, into: %{} do
        attempt_map = for %Team{id: lead_team_id} <- teams, into: %{}, do: {lead_team_id, nil}
        {current_team_id, attempt_map}
      end

    round |> where(attempts_by_team_id: attempts_by_team_id)
  end

  def get_score(%__MODULE__{} = round, teams) do
    matchups =
      for decipherer_team <- teams,
          encipherer_team <- teams,
          into: [],
          do: {decipherer_team, encipherer_team}

    score_by_team_id = for team <- teams, into: %{}, do: {team.id, 0}

    matchups
    |> List.foldl(score_by_team_id, fn matchup, score_by_team_id ->
      {decipherer_team, _} = matchup

      score_by_team_id
      |> Map.update!(decipherer_team.id, fn score -> score + get_vs_score(round, matchup) end)
    end)
  end

  defp get_vs_score(%__MODULE__{} = round, {decipherer_team, encipherer_team}) do
    correct_code = round |> get_code(encipherer_team.id)
    attempt = round |> get_attempt(decipherer_team.id, encipherer_team.id)

    if attempt == correct_code do
      if decipherer_team != encipherer_team, do: 1, else: 0
    else
      if decipherer_team == encipherer_team, do: -1, else: 0
    end
  end
end
