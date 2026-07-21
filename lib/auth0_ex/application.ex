defmodule Auth0Ex.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Token fetches run here rather than inside TokenState, so a slow request to
      # Auth0 cannot block callers that already hold a valid token.
      {Task.Supervisor, name: Auth0Ex.TaskSupervisor},
      {Auth0Ex.TokenState, []}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Auth0Ex.Supervisor)
  end
end
