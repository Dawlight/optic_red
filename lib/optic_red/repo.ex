defmodule OpticRed.Repo do
  use Ecto.Repo,
    otp_app: :optic_red,
    adapter: Ecto.Adapters.Postgres
end
