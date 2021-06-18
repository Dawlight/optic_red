defmodule OpticRedWeb.Plugs.PlayerId do
  import Plug.Conn

  @session_key "player_id"

  def init(options), do: options

  def call(conn, _default) do
    player_id = get_session(conn, @session_key)

    case player_id do
      nil ->
        player_id = :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
        put_session(conn, @session_key, player_id)

      _ ->
        conn
    end
  end
end
