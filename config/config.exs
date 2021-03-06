# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :optic_red,
  ecto_repos: [OpticRed.Repo]

# Configures the endpoint
config :optic_red, OpticRedWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "5xOnZTWzGwNit3dZ82Ok3Znjt0XdYFINwgvRuuhF423rAYifueITbBrBlJc8rI54",
  render_errors: [view: OpticRedWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: OpticRed.PubSub,
  live_view: [signing_salt: "++3OCpTrtm4NeEjy+wnJ4kQfdrocwIav"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
