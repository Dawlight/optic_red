defmodule OpticRedWeb.Live.Components.TeamJoinButton do
  use Phoenix.Component
  use Phoenix.Template, root: "lib/optic_red_web/live/components"

  alias AftermathWeb.LiveHelpers
  alias OpticRed.Game.Model.Team

  def render(assigns) do
    render_template("team_join_button.html", assigns)
  end

  def button_disabled?(team, teams, players, current_player_id) do
    assigned_player_count =
      players |> Enum.filter(fn player -> player.team_id != nil end) |> Enum.count()

    current_player = players |> Enum.find(nil, fn player -> player.id == current_player_id end)

    team_count = teams |> Enum.count()

    team_count_average =
      case current_player.team_id do
        nil ->
          assigned_player_count / team_count

        _ ->
          (assigned_player_count - 1) / team_count
      end

    team_player_count = players |> Enum.count(fn player -> player.team_id == team.id end)

    team_player_count > team_count_average
  end

  def get_classes(team, players, current_player_id) do
    ["button", "is-medium", "is-rounded", "is-fullwidth"]
    |> add_team_color(team, players, current_player_id)
    |> Enum.join(" ")
  end

  defp add_team_color(classes, %Team{id: team_id}, players, current_player_id) do
    current_player = players |> Enum.find(nil, fn player -> player.id == current_player_id end)

    case current_player.team_id do
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
