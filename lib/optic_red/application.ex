defmodule OpticRed.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      OpticRed.Repo,
      # Start the Telemetry supervisor
      OpticRedWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: OpticRed.PubSub},
      OpticRed.Presence,
      # Start the Endpoint (http/https)
      OpticRedWeb.Endpoint,
      # Start a worker by calling: OpticRed.Worker.start_link(arg)
      # {OpticRed.Worker, arg}
      OpticRed.Lobby.Supervisor
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: OpticRed.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    OpticRedWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
