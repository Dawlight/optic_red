defmodule OpticRed.Game do
  use Supervisor

  def start_link(%{game_id: game_id} = args) do
    IO.inspect("STARTING!")
    name = get_game_id_name(game_id)
    Supervisor.start_link(__MODULE__, args, name: {:via, :gproc, name})
  end

  @impl Supervisor
  def init(args) do
    children = [
      {OpticRed.GameState, args}
      # {OpticRed.GameCoordinator, [args]}
    ]

    IO.inspect("CONTINUING #{__MODULE__}")
    Supervisor.init(children, strategy: :rest_for_one)
  end

  defp get_game_id_name(game_id) do
    {:n, :l, {:game_state_supervisor, game_id}}
  end
end
