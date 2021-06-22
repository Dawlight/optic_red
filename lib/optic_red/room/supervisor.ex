defmodule OpticRed.Room.Supervisor do
  use Supervisor

  def start_link(room_id) do
    {:ok, _} =
      Supervisor.start_link(__MODULE__, room_id,
        name: {:via, :gproc, get_room_supervisor_name(room_id)}
      )
  end

  @impl Supervisor
  def init(room_id) do
    children = [
      {OpticRed.Room, room_id},
      {OpticRed.Game,
       %{
         room_id: room_id,
         teams: [:red, :blue]
       }}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end

  defp get_room_supervisor_name(room_id) do
    {:n, :l, {:room_supervisor, room_id}}
  end
end
