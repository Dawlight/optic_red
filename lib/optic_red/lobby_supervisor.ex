defmodule OpticRed.Lobby.Supervisor do
  use DynamicSupervisor

  def start_link(args) do
    DynamicSupervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def create_room(room_id) do
    spec = %{
      id: OpticRed.Room,
      start: {OpticRed.Room, :start_link, [room_id]},
      restart: :temporary,
      modules: :dynamic
    }

    {:ok, _} = DynamicSupervisor.start_child(__MODULE__, spec)
  end

  @impl DynamicSupervisor
  def init(_args) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
