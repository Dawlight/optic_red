defmodule OpticRed.Presence do
  use Phoenix.Presence,
    otp_app: :optic_red,
    pubsub_server: OpticRed.PubSub
end
