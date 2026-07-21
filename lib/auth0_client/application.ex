defmodule Auth0Client.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    Auth0Client.Config.warn_if_tls_verification_disabled()

    children = [
      # Token fetches run here rather than inside TokenState, so a slow request to
      # Auth0 cannot block callers that already hold a valid token.
      {Task.Supervisor, name: Auth0Client.TaskSupervisor},
      {Auth0Client.TokenState, []}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Auth0Client.Supervisor)
  end
end
