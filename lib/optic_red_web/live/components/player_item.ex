defmodule OpticRedWeb.Live.Components.PlayerItem do
  use Phoenix.Component
  use Phoenix.Template, root: "lib/optic_red_web/live/components"

  alias AftermathWeb.LiveHelpers

  def render(assigns) do
    render_template("player_item.html", assigns)
  end

  def get_classes(player, player_team_map, current_player_id) do
    []
    |> add_team_color(player, player_team_map, current_player_id)
    |> add_highlight(player, current_player_id)
    |> Enum.join(" ")
  end

  defp add_team_color(classes, player, player_team_map, current_player_id) do
    case player_team_map[player.id] do
      "red" -> ["is-danger" | classes]
      "blue" -> ["is-info" | classes]
      nil -> classes
    end
  end

  defp add_highlight(classes, player, current_player_id) do
    case player.id == current_player_id do
      true -> ["has-text-weight-bold" | classes]
      false -> classes
    end
  end
end
