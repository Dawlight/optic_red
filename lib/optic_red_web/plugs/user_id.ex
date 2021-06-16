defmodule OpticRedWeb.Plugs.UserId do
  import Plug.Conn

  def init(options), do: options

  def call(conn, _default) do
    user_id = get_session(conn, "user_id")

    case user_id do
      nil ->
        user_id = :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
        put_session(conn, "user_id", user_id)

      _ ->
        conn
    end
  end
end
