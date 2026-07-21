defmodule Auth0Ex.Management.Session do
  @moduledoc """
  A module representing session resource.

  Addresses one session at a time. To find the ids, list a user's sessions with
  `Auth0Ex.Management.User.sessions/2`; to end all of them at once, use
  `Auth0Ex.Management.User.delete_sessions/1`.
  """
  use Auth0Ex.Api, for: :mgmt
  @path "sessions"

  @doc """
  Gets a session

      iex> Auth0Ex.Management.Session.get("sess_abc123")
  """
  def get(id) when is_binary(id) do
    do_get("#{@path}/#{id}")
  end

  @doc """
  Updates a session's metadata

  `session_metadata` is the only mutable property, and at least one property must be
  present. Passing `nil` or `%{}` **clears** the metadata rather than leaving it
  alone — an explicit null is meaningful here, which is why this library does not
  prune nils from Management PATCH bodies.

      iex> Auth0Ex.Management.Session.update("sess_abc123", %{session_metadata: %{device: "laptop"}})
      iex> Auth0Ex.Management.Session.update("sess_abc123", %{session_metadata: nil})
  """
  def update(id, body) when is_binary(id) do
    do_patch("#{@path}/#{id}", body)
  end

  @doc """
  Deletes a session

  Ends the session and **leaves its refresh tokens alive**, so an application holding
  one can obtain a new access token immediately. Use `revoke/1` after a credential
  compromise.

  Answers `202`.

      iex> Auth0Ex.Management.Session.delete("sess_abc123")
  """
  def delete(id) when is_binary(id) do
    do_delete("#{@path}/#{id}")
  end

  @doc """
  Revokes a session and every refresh token issued under it

  The difference from `delete/1`: this one closes the refresh-token path too, so the
  user genuinely has to authenticate again.

  Answers `202`.

      iex> Auth0Ex.Management.Session.revoke("sess_abc123")
  """
  def revoke(id) when is_binary(id) do
    do_post("#{@path}/#{id}/revoke")
  end
end
