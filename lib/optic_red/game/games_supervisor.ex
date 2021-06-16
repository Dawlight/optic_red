defmodule OpticRed.Game.GamesSupervisor do
  use DynamicSupervisor

  def start_link(args) do
    DynamicSupervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def start_game(args) do
    spec = %{
      id: OpticRed.Game.Supervisor,
      start: {OpticRed.Game.Supervisor, :start_link, [args]},
      restart: :temporary,
      modules: :dynamic
    }

    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  @impl DynamicSupervisor
  def init(_args) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
