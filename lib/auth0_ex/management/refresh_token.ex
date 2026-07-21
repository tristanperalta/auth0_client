defmodule Auth0Ex.Management.RefreshToken do
  @moduledoc """
  A module representing refresh token resource.

  Addresses one refresh token at a time, and revokes them in bulk. To list a single
  user's tokens from the user's side, `Auth0Ex.Management.User.refresh_tokens/2` is
  the equivalent of `all/1`; to delete all of them,
  `Auth0Ex.Management.User.delete_refresh_tokens/1`.

  To revoke a refresh token as its holder rather than as an administrator — no
  Management token involved — use `Auth0Ex.Authentication.Token.revoke/3`.
  """
  use Auth0Ex.Api, for: :mgmt
  @path "refresh-tokens"

  @doc """
  Gets a user's refresh tokens

  **`user_id` is required.** `client_id` narrows the result to one application, which
  is what this endpoint offers over `Auth0Ex.Management.User.refresh_tokens/2` — they
  otherwise return the same tokens. Results are sorted by `credential_id` ascending
  and use checkpoint pagination (`from`, `take`).

  Auth0 lists this endpoint as Early Access.

      iex> Auth0Ex.Management.RefreshToken.all(user_id: "auth0|23423")
      iex> Auth0Ex.Management.RefreshToken.all(%{user_id: "auth0|23423", client_id: "abc123"})
  """
  def all(params) when is_map(params) or is_list(params) do
    do_get(@path, params)
  end

  @doc """
  Gets a refresh token

      iex> Auth0Ex.Management.RefreshToken.get("rt_abc123")
  """
  def get(id) when is_binary(id) do
    do_get("#{@path}/#{id}")
  end

  @doc """
  Updates a refresh token's metadata

  `refresh_token_metadata` is the only mutable property, and at least one property
  must be present. Passing `nil` or `%{}` **clears** the metadata rather than leaving
  it alone.

      iex> Auth0Ex.Management.RefreshToken.update("rt_abc123", %{refresh_token_metadata: %{app: "ios"}})
  """
  def update(id, body) when is_binary(id) do
    do_patch("#{@path}/#{id}", body)
  end

  @doc """
  Deletes a refresh token

  Answers `202`.

      iex> Auth0Ex.Management.RefreshToken.delete("rt_abc123")
  """
  def delete(id) when is_binary(id) do
    do_delete("#{@path}/#{id}")
  end

  @doc """
  Revokes refresh tokens in bulk

  The body is an **exclusive choice**, not a set of filters. Auth0 accepts exactly one
  of these four shapes:

    * `ids` — up to 100 token ids, and combinable with nothing else
    * `user_id` — every token the user holds
    * `user_id` + `client_id` — narrowed to one application
    * `user_id` + `client_id` + `audience` — narrowed further to one API

  `client_id` on its own is rejected, and `audience` requires both of the others.

  Answers `202`. Auth0 lists this endpoint as Early Access.

      iex> Auth0Ex.Management.RefreshToken.revoke(%{ids: ["rt_abc123", "rt_def456"]})
      iex> Auth0Ex.Management.RefreshToken.revoke(%{user_id: "auth0|23423", client_id: "abc123"})
  """
  def revoke(body) do
    do_post("#{@path}/revoke", body)
  end
end
