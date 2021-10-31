# defmodule OpticRedWeb.Live.RoundEndLive do
#   use OpticRedWeb, :live_component

#   alias OpticRed.Game.State
#   alias OpticRed.Game.Model.Data
#   alias OpticRed.Game.Model.Team
#   alias OpticRed.Game.Model.TeamRound

#   @default_assigns %{
#     teams: [],
#     players: [],
#     player_team_map: %{},
#     current_player_id: nil
#   }

#   def mount(socket) do
#     {:ok, assign(socket, @default_assigns)}
#   end

#   def update(assigns, socket) do
#     {:ok, assign(socket, assigns)}
#   end

#   def lead_team_clues(assigns) do
#     %State{data: %Data{rounds: rounds, lead_team_id: lead_team_id}} = assigns[:game_state]

#     [current_round | _] = rounds
#     %TeamRound{clues: clues} = current_round[lead_team_id]
#     clues
#   end

#   def get_attempts(assigns, team_id) do
#     %State{data: %Data{rounds: rounds}} = assigns[:game_state]
#     [current_round | _] = rounds

#     current_round[team_id].attempts
#   end

#   def get_code(assigns, team_id) do
#     %State{data: %Data{rounds: rounds}} = assigns[:game_state]
#     [current_round | _] = rounds

#     current_round[team_id].code
#   end

#   def lead_team_id(assigns) do
#     %State{data: %Data{lead_team_id: lead_team_id}} = assigns[:game_state]
#     lead_team_id
#   end

#   def current_team_id(assigns) do
#     current_player_id = assigns[:current_player_id]
#     player_team_map = assigns[:player_team_map]
#     player_team_map[current_player_id]
#   end
# end
