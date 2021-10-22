defmodule OpticRedWeb.Live.Components.TeamJoinButton do
  use Phoenix.Component
  use Phoenix.Template, root: "lib/optic_red_web/live/components"

  alias AftermathWeb.LiveHelpers
  alias OpticRed.Game.State.Team

  def render(assigns) do
    render_template("team_join_button.html", assigns)
  end

  def button_disabled?(team, teams, player_team_map, current_player_id) do
    team_count_map =
      for %Team{id: team_id} <- teams,
          do: {team_id, get_player_count(team_id, player_team_map)},
          into: %{}

    team_count_map |> IO.inspect(label: "WPOWOWOWOWO")
    assigned_player_count = player_team_map |> Enum.count()
    team_count = teams |> Enum.count()

    team_count_average =
      case player_team_map[current_player_id] do
        nil ->
          assigned_player_count / team_count

        _ ->
          (assigned_player_count - 1) / team_count
      end

    team_count_map[team.id] > team_count_average
  end

  defp get_player_count(team_id, player_team_map) do
    player_team_map
    |> Enum.count(fn {_, assigned_team_id} -> assigned_team_id == team_id end)
  end

  def get_classes(team, player_team_map, current_player_id) do
    ["button", "is-fullwidth", "mb-2"]
    |> add_team_color(team, player_team_map, current_player_id)
    |> Enum.join(" ")
  end

  defp add_team_color(classes, %Team{id: team_id}, player_team_map, current_player_id) do
    case player_team_map[current_player_id] do
      ^team_id ->
        classes

      _ ->
        case team_id do
          "red" -> ["is-danger" | classes]
          "blue" -> ["is-info" | classes]
          nil -> classes
        end
    end
  end
end
