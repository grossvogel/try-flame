defmodule TryFlame.Repo do
  use Ecto.Repo,
    otp_app: :try_flame,
    adapter: Ecto.Adapters.Postgres
end
