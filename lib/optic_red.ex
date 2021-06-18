defmodule OpticRed do
  @moduledoc """
  OpticRed keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  def create_new_room() do
    room_id = :crypto.strong_rand_bytes(4) |> Base.url_encode64(padding: false)
    {:ok, _pid} = OpticRed.Lobby.Supervisor.create_room(room_id)

    {:ok, room_id}
  end
end
