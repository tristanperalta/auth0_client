defmodule Auth0Client.Management.Grant do
  @moduledoc """
  A module representing grants on Auth0.

  A grant is a user's recorded consent for an application — which scopes they
  agreed to, for which audience. Deleting one makes Auth0 prompt the user for
  consent again, and invalidates the refresh tokens issued under it.

  https://auth0.com/docs/api/management/v2/grants
  """

  use Auth0Client.Api, for: :mgmt
  @path "grants"

  @doc """
  Gets all grants.

  Filter with `user_id`, `client_id` or `audience`; paginate with `page`,
  `per_page` and `include_totals`.

      iex> Auth0Client.Management.Grant.all()
      iex> Auth0Client.Management.Grant.all(user_id: "auth0|abc123")
  """
  def all(params \\ %{}) when is_map(params) or is_list(params) do
    do_get(@path, params)
  end

  @doc """
  Deletes a single grant by its id.

  The user is prompted for consent the next time the application asks, and the
  refresh tokens issued under this grant stop working.

      iex> Auth0Client.Management.Grant.delete("cgr_abc123")
  """
  def delete(id) when is_binary(id), do: do_delete("#{@path}/#{id}")

  @doc """
  Deletes every grant belonging to a user.

  Auth0 takes the user id as a query parameter here rather than a path segment,
  which is why this is a separate function from `delete/1`.

  This revokes all of the user's consents at once — every application they have
  authorised will prompt again, and every refresh token issued under those grants
  stops working. To revoke one application's access, use `delete/1` with that
  grant's id.

      iex> Auth0Client.Management.Grant.delete_by_user("auth0|abc123")
  """
  def delete_by_user(user_id) when is_binary(user_id) do
    do_delete(@path, %{user_id: user_id})
  end
end
