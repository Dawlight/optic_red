# defmodule OpticRed.Game.State.Decipher do
#   alias OpticRed.Game.State.Data

#   defstruct data: %Data{},
#             codes: %{},
#             clues: %{},
#             attempts: %{},
#             lead_team: nil,
#             previous_lead_teams: []

#   alias OpticRed.Game.State.RoundEnd
#   alias OpticRed.Game.State.GameEnd

#   alias OpticRed.Game.Event.AttemptSubmitted

#   def new(%Data{team_map: team_map} = data, codes, clues) do
#     [first_team | _] = team_map |> Enum.map(fn {_, team} -> team end)

#     attempt_map = for {_, team} <- team_map, into: %{}, do: {team.id, nil}
#     attempts = for {_, team} <- team_map, into: %{}, do: {team.id, attempt_map}

#     %__MODULE__{
#       data: data,
#       codes: codes,
#       clues: clues,
#       attempts: attempts,
#       lead_team: first_team
#     }
#   end

#   def with_next_lead_team(%__MODULE__{} = state) do
#     %__MODULE__{data: %Data{team_map: team_map}, previous_lead_teams: previous_lead_teams} = state
#     [first_team | _] = (team_map |> Enum.map(fn {_, team} -> team end)) -- previous_lead_teams

#     %__MODULE__{state | lead_team: first_team}
#   end

#   def apply_event(%__MODULE__{} = state, %AttemptSubmitted{} = event) do
#     %__MODULE__{
#       data: data,
#       attempts: attempts,
#       lead_team: lead_team
#     } = state

#     %AttemptSubmitted{team_id: team_id, attempt: attempt} = event

#     attempts = put_in(attempts[team_id][lead_team.id], attempt)

#     case have_all_teams_submitted?(state) do
#       false ->
#         %__MODULE__{state | attempts: attempts}

#       true ->
#         case have_all_teams_been_lead?(state) |> IO.inspect(label: "All teams have been lead?") do
#           true ->
#             # data = update_score(data)

#             case has_any_team_won?(data) do
#               true ->
#                 GameEnd.new(data)

#               false ->
#                 RoundEnd.new(data)
#             end

#           false ->
#             __MODULE__.with_next_lead_team(state)
#         end
#     end
#   end

#   defp has_any_team_won?(%Data{target_score: target_score} = data) do
#     Enum.any?(Map.values(data.team_score_map), fn score -> score >= target_score end)
#   end

#   defp have_all_teams_submitted?(%__MODULE__{attempts: attempts, lead_team: lead_team}) do
#     Enum.all?(attempts, fn {_, attempt_map} -> attempt_map[lead_team.id] != nil end)
#   end

#   defp have_all_teams_been_lead?(%__MODULE__{} = state) do
#     %__MODULE__{
#       data: %Data{team_map: team_map},
#       lead_team: lead_team,
#       previous_lead_teams: previous_lead_teams
#     } = state

#     teams = team_map |> Enum.map(fn {_, team} -> team end)

#     teams == [lead_team | previous_lead_teams]
#   end

#   # defp update_score(data) do
#   #   %Data{team_map: team_map, team_score_map: team_score_map} = data
#   #   [current_round | _] = rounds
#   #   round_score = get_round_score(team_map, current_round)
#   #   total_score = Map.merge(team_score_map, round_score, fn _, x, y -> x + y end)
#   #   put_in(data.team_score_map, total_score)
#   # end

#   # defp get_round_score(team_map, round) do
#   #   matchups =
#   #     for {deciphering_team_id, _} <- team_map,
#   #         {enciphering_team_id, _} <- team_map,
#   #         do: {deciphering_team_id, enciphering_team_id}

#   #   Enum.reduce(matchups, %{}, fn {dec_team_id, enc_team_id}, score_totals ->
#   #     score = get_team_vs_team_round_score(dec_team_id, enc_team_id, round)
#   #     Map.update(score_totals, dec_team_id, score, fn current_score -> current_score + score end)
#   #   end)
#   # end

#   # defp get_team_vs_team_round_score(desciphering_team, enciperhing_team, round) do
#   #   attempt = round[desciphering_team].attempts[enciperhing_team]
#   #   code = round[enciperhing_team].code

#   #   cond do
#   #     # Bad attempt at own team's code
#   #     attempt != code and enciperhing_team === desciphering_team -> -2
#   #     # Good attempt at opposing team's code
#   #     attempt === code and enciperhing_team !== desciphering_team -> 1
#   #     # Otherwise no points
#   #     true -> 0
#   #   end
#   # end
# end
