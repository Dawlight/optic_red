defmodule OpticRedWeb.HomeLive do
  use OpticRedWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, test: "Hello!")}
  end

  @impl
  def handle_event("button_click", _value, socket) do
    {:noreply, assign(socket, test: "Boo!")}
  end
end
