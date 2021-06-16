defmodule OpticRedWeb.Live.Game do
  use OpticRedWeb, :live_view

  alias Phoenix.PubSub

  @impl true
  def mount(params, session, socket) do
    IO.inspect(session, label: "session")

    {:ok, assign(socket, test: "Hello!")}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end
end
