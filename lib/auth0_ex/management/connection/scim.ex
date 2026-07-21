defmodule Auth0Ex.Management.Connection.Scim do
  @moduledoc """
  SCIM configuration for a connection — inbound user provisioning.

  An external identity provider pushes users into Auth0 over SCIM 2.0, authenticating
  with a token issued by `create_token/2`. For the other direction — Auth0 pulling users
  and groups out of a directory — see `Auth0Ex.Management.Connection.DirectoryProvisioning`.

  **Every function except `all/1` takes a connection id**, not a SCIM-configuration id.
  A connection has at most one SCIM configuration, so there is nothing else to address
  it by.
  """
  use Auth0Ex.Api, for: :mgmt
  @path "connections"

  @doc """
  Gets every SCIM configuration in the tenant

  Uses checkpoint pagination: omit `from` on the first call, then pass the `next` value
  from the response.

      iex> Auth0Ex.Management.Connection.Scim.all()
      iex> Auth0Ex.Management.Connection.Scim.all(take: 50)
  """
  def all(params \\ %{}) when is_map(params) or is_list(params) do
    do_get("connections-scim-configurations", params)
  end

  @doc """
  Gets a connection's SCIM configuration

      iex> Auth0Ex.Management.Connection.Scim.get("some_conn_id")
  """
  def get(connection_id) do
    do_get("#{@path}/#{connection_id}/scim-configuration")
  end

  @doc """
  Creates a SCIM configuration for a connection

  `user_id_attribute` names the SCIM field to derive unique user ids from. `mapping`
  is a list of `%{auth0: _, scim: _}` pairs; omit both to accept the defaults, which
  `default_mapping/1` reports.

      iex> Auth0Ex.Management.Connection.Scim.create("some_conn_id")
      iex> Auth0Ex.Management.Connection.Scim.create("some_conn_id", %{
      ...>   user_id_attribute: "externalId",
      ...>   mapping: [%{auth0: "email", scim: "userName"}]
      ...> })
  """
  def create(connection_id, body \\ %{}) do
    do_post("#{@path}/#{connection_id}/scim-configuration", body)
  end

  @doc """
  Updates a connection's SCIM configuration

  A PATCH, but Auth0 requires **both** `user_id_attribute` and `mapping` — send the
  whole configuration, not the part you are changing.

      iex> Auth0Ex.Management.Connection.Scim.update("some_conn_id", %{
      ...>   user_id_attribute: "externalId",
      ...>   mapping: [%{auth0: "email", scim: "userName"}]
      ...> })
  """
  def update(connection_id, body) do
    do_patch("#{@path}/#{connection_id}/scim-configuration", body)
  end

  @doc """
  Deletes a connection's SCIM configuration

      iex> Auth0Ex.Management.Connection.Scim.delete("some_conn_id")
  """
  def delete(connection_id) do
    do_delete("#{@path}/#{connection_id}/scim-configuration")
  end

  @doc """
  Gets the default SCIM mapping for a connection

  What Auth0 uses when `create/2` is called without a `mapping` — useful as the
  starting point for a custom one.

      iex> Auth0Ex.Management.Connection.Scim.default_mapping("some_conn_id")
  """
  def default_mapping(connection_id) do
    do_get("#{@path}/#{connection_id}/scim-configuration/default-mapping")
  end

  @doc """
  Gets the SCIM tokens for a connection

  The token values themselves are returned only by `create_token/2`.

      iex> Auth0Ex.Management.Connection.Scim.tokens("some_conn_id")
  """
  def tokens(connection_id) do
    do_get("#{@path}/#{connection_id}/scim-configuration/tokens")
  end

  @doc """
  Creates a SCIM token for a connection

  `token_lifetime` is in seconds and must be greater than 900. **The token value is
  returned once, here** — Auth0 will not show it again, so store it when you create it.

      iex> Auth0Ex.Management.Connection.Scim.create_token("some_conn_id", %{
      ...>   scopes: ["get:users", "post:users"],
      ...>   token_lifetime: 86_400
      ...> })
  """
  def create_token(connection_id, body \\ %{}) do
    do_post("#{@path}/#{connection_id}/scim-configuration/tokens", body)
  end

  @doc """
  Deletes a SCIM token

      iex> Auth0Ex.Management.Connection.Scim.delete_token("some_conn_id", "some_token_id")
  """
  def delete_token(connection_id, token_id) do
    do_delete("#{@path}/#{connection_id}/scim-configuration/tokens/#{token_id}")
  end
end
