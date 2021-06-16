defmodule OpticRed.Game.Supervisor do
  use Supervisor

  def start_link(%{game_id: game_id} = args) do
    IO.inspect("STARTING!")
    name = get_game_id_name(game_id)
    Supervisor.start_link(__MODULE__, args, name: {:via, :gproc, name})
  end

  @impl Supervisor
  def init(args) do
    game_state_args = %{game_id: _, teams: _} = args

    children = [
      {OpticRed.Game.State, game_state_args}
      # {OpticRed.GameCoordinator, [args]}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end

  defp get_game_id_name(game_id) do
    {:n, :l, {:game_state_supervisor, game_id}}
  end
end
