defmodule OpticRed.Game do
  def start_new() do
    game_id =
      :crypto.strong_rand_bytes(4)
      |> Base.url_encode64(padding: false)

    teams = [:red, :blue]
    {:ok, _} = OpticRed.Game.GamesSupervisor.start_game(%{game_id: game_id, teams: teams})
    {:ok, game_id}
  end
end
