defmodule Auth0Client.EnvCase do
  @moduledoc """
  Snapshot and restore of `:auth0_client` application environment.

  Most of what `Auth0Client.Config` reads is global, so a test that changes a
  setting has to put it back. `import Auth0Client.EnvCase` and declare the keys.
  """

  @doc """
  Restores the given `:auth0_client` env keys to their current values on exit.

  A key that is unset now is deleted rather than set to `nil` on the way out —
  the two are not the same to `Application.get_env/3`, whose default only applies
  to an absent key.

      setup do
        restore_env_on_exit([:domain, :custom_domain])
      end

  Register this *after* any other `on_exit/1` the setup needs. Callbacks run in
  reverse order of registration, so registering it last means the environment is
  restored before those callbacks run, not after.
  """
  def restore_env_on_exit(keys) when is_list(keys) do
    original = Map.new(keys, &{&1, Application.get_env(:auth0_client, &1)})

    ExUnit.Callbacks.on_exit(fn ->
      Enum.each(original, fn
        {key, nil} -> Application.delete_env(:auth0_client, key)
        {key, value} -> Application.put_env(:auth0_client, key, value)
      end)
    end)
  end
end
