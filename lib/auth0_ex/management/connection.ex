defmodule Auth0Ex.Management.Connection do
  @moduledoc """
  A module representing connection resource
  """
  use Auth0Ex.Api, for: :mgmt
  @path "connections"

  @doc """
  Gets all the connections

  Past 1,000 connections, offset pagination stops working — use checkpoint
  pagination instead, passing `from` and `take`.

      iex> Auth0Ex.Management.Connection.all()
      iex> Auth0Ex.Management.Connection.all(%{name: "some_name"})
      iex> Auth0Ex.Management.Connection.all(take: 100)
  """
  def all(params \\ %{}) when is_map(params) or is_list(params) do
    do_get(@path, params)
  end

  @doc """
  Get a connection

      iex> Auth0Ex.Management.Connection.get("some_conn_id")
      iex> Auth0Ex.Management.Connection.get("some_conn_id", [fields: "id,name"])
  """
  def get(id) when is_binary(id), do: get(id, [])

  def get(id, params) when is_binary(id) and (is_map(params) or is_list(params)) do
    do_get("#{@path}/#{id}", params)
  end

  @doc """
  Creates a new connection

      iex> Auth0Ex.Management.Connection.create(%{name: "some_name", strategy: "email"})
  """
  def create(body) do
    do_post("#{@path}", body)
  end

  @doc """
  Update a connection

  `name` and `strategy` are immutable — Auth0 rejects an attempt to change either,
  so a connection has to be recreated to rename it.

  `enabled_clients` is superseded by `update_clients/2`, which changes one client at a
  time rather than replacing the whole list.

      iex> Auth0Ex.Management.Connection.update("some_conn_id", %{display_name: "New name"})
      iex> Auth0Ex.Management.Connection.update("some_conn_id", %{options: %{brute_force_protection: true}})
  """
  def update(id, body) do
    do_patch("#{@path}/#{id}", body)
  end

  @doc """
  Delete a connection

      iex> Auth0Ex.Management.Connection.delete("some_conn_id")
  """
  def delete(id) do
    do_delete("#{@path}/#{id}")
  end

  @doc """
  Delete a specified connection user by its email

      iex> Auth0Ex.Management.Connection.delete_conn_user("some_conn_id", "samar@example.com")
  """
  def delete_conn_user(id, email) do
    do_delete("#{@path}/#{id}/users", %{email: email})
  end

  @doc """
  Gets the clients that have this connection enabled

  The mirror of `Auth0Ex.Management.Client.connections/2`. Uses checkpoint pagination:
  omit `from` on the first call, then pass the `next` value from the response.

      iex> Auth0Ex.Management.Connection.clients("some_conn_id")
      iex> Auth0Ex.Management.Connection.clients("some_conn_id", take: 50)
  """
  def clients(id, params \\ %{}) when is_map(params) or is_list(params) do
    do_get("#{@path}/#{id}/clients", params)
  end

  @doc """
  Enables or disables this connection for the given clients

  Takes a list of `%{client_id: _, status: _}` — a JSON array, not an object — and
  changes only the clients named. Auth0 accepts at most 50 per request. This is the
  replacement for setting `enabled_clients` through `update/2`, which replaces the
  entire list and so races with anyone else editing the connection.

  Returns `:ok`; Auth0 answers 204 with no body.

      iex> Auth0Ex.Management.Connection.update_clients("some_conn_id", [
      ...>   %{client_id: "abc123", status: true},
      ...>   %{client_id: "def456", status: false}
      ...> ])
  """
  def update_clients(id, clients) when is_list(clients) do
    do_patch("#{@path}/#{id}/clients", clients)
  end

  @doc """
  Gets the connection keys

  Okta and OIDC strategies only.

      iex> Auth0Ex.Management.Connection.keys("some_conn_id")
  """
  def keys(id) do
    do_get("#{@path}/#{id}/keys")
  end

  @doc """
  Provisions the initial connection keys

  Okta and OIDC strategies only. Create the keys *before* configuring the connection
  to use Private Key JWT, so the transition needs no downtime.

  `signing_alg` is one of `RS256`, `RS384`, `RS512`, `PS256`, `PS384`, `ES256` or
  `ES384`.

      iex> Auth0Ex.Management.Connection.create_keys("some_conn_id", %{signing_alg: "RS256"})
  """
  def create_keys(id, body \\ %{}) do
    do_post("#{@path}/#{id}/keys", body)
  end

  @doc """
  Rotates the connection keys

      iex> Auth0Ex.Management.Connection.rotate_keys("some_conn_id")
      iex> Auth0Ex.Management.Connection.rotate_keys("some_conn_id", %{signing_alg: "RS256"})
  """
  def rotate_keys(id, body \\ %{}) do
    do_post("#{@path}/#{id}/keys/rotate", body)
  end

  @doc """
  Checks whether an AD/LDAP connection is online

  **A 404 here means the connection is offline**, not that it does not exist — that is
  how Auth0 reports the state, so it arrives as an error like any other 404:

      case Auth0Ex.Management.Connection.status(conn_id) do
        {:ok, _} -> :online
        {:error, %Auth0Ex.Error{status: 404}} -> :offline
        {:error, error} -> {:error, error}
      end

      iex> Auth0Ex.Management.Connection.status("some_conn_id")
  """
  def status(id) do
    do_get("#{@path}/#{id}/status")
  end
end
