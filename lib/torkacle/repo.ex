defmodule Torkacle.Repo do
  use Ecto.Repo,
    otp_app: :torkacle,
    adapter: Ecto.Adapters.Postgres
end
