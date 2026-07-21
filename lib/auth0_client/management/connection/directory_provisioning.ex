defmodule Auth0Client.Management.Connection.DirectoryProvisioning do
  @moduledoc """
  Directory provisioning for a connection — outbound user and group synchronization.

  Auth0 reads users and groups out of the connection's directory, on a schedule or on
  demand. For the other direction — an identity provider pushing users into Auth0 —
  see `Auth0Client.Management.Connection.Scim`.

  **Every function except `all/1` takes a connection id**, not a configuration id. A
  connection has at most one directory provisioning configuration.
  """
  use Auth0Client.Api, for: :mgmt
  @path "connections"

  @doc """
  Gets every directory provisioning configuration in the tenant

  Uses checkpoint pagination: omit `from` on the first call, then pass the `next` value
  from the response.

      iex> Auth0Client.Management.Connection.DirectoryProvisioning.all()
      iex> Auth0Client.Management.Connection.DirectoryProvisioning.all(take: 50)
  """
  def all(params \\ %{}) when is_map(params) or is_list(params) do
    do_get("connections-directory-provisionings", params)
  end

  @doc """
  Gets a connection's directory provisioning configuration

      iex> Auth0Client.Management.Connection.DirectoryProvisioning.get("some_conn_id")
  """
  def get(connection_id) do
    do_get("#{@path}/#{connection_id}/directory-provisioning")
  end

  @doc """
  Creates a directory provisioning configuration for a connection

  `mapping` is a list of `%{auth0: _, idp: _}` pairs — both keys are required on each.
  `synchronize_groups` is `"all"`, `"off"` or `"selected"`; under `"selected"`, name the
  groups with `replace_synchronized_groups/2`.

      iex> Auth0Client.Management.Connection.DirectoryProvisioning.create("some_conn_id", %{
      ...>   mapping: [%{auth0: "email", idp: "mail"}],
      ...>   synchronize_automatically: true,
      ...>   synchronize_groups: "all"
      ...> })
  """
  def create(connection_id, body \\ %{}) do
    do_post("#{@path}/#{connection_id}/directory-provisioning", body)
  end

  @doc """
  Updates a connection's directory provisioning configuration

  Switching `synchronize_groups` to `"selected"` does not by itself narrow anything —
  the selection lives in `replace_synchronized_groups/2`.

      iex> Auth0Client.Management.Connection.DirectoryProvisioning.update("some_conn_id", %{
      ...>   synchronize_automatically: false
      ...> })
  """
  def update(connection_id, body) do
    do_patch("#{@path}/#{connection_id}/directory-provisioning", body)
  end

  @doc """
  Deletes a connection's directory provisioning configuration

      iex> Auth0Client.Management.Connection.DirectoryProvisioning.delete("some_conn_id")
  """
  def delete(connection_id) do
    do_delete("#{@path}/#{connection_id}/directory-provisioning")
  end

  @doc """
  Gets the default attribute mapping for a connection

  What Auth0 uses when `create/2` is called without a `mapping`.

      iex> Auth0Client.Management.Connection.DirectoryProvisioning.default_mapping("some_conn_id")
  """
  def default_mapping(connection_id) do
    do_get("#{@path}/#{connection_id}/directory-provisioning/default-mapping")
  end

  @doc """
  Requests an on-demand synchronization of the directory

  Independent of `synchronize_automatically`. Auth0 answers 201 once the run is
  accepted, not once it finishes.

      iex> Auth0Client.Management.Connection.DirectoryProvisioning.synchronize("some_conn_id")
  """
  def synchronize(connection_id) do
    do_post("#{@path}/#{connection_id}/directory-provisioning/synchronizations")
  end

  @doc """
  Gets the groups selected for synchronization

  Meaningful only under `synchronize_groups: "selected"`.

      iex> Auth0Client.Management.Connection.DirectoryProvisioning.synchronized_groups("some_conn_id")
      iex> Auth0Client.Management.Connection.DirectoryProvisioning.synchronized_groups("some_conn_id", take: 50)
  """
  def synchronized_groups(connection_id, params \\ %{}) when is_map(params) or is_list(params) do
    do_get("#{@path}/#{connection_id}/directory-provisioning/synchronized-groups", params)
  end

  @doc """
  Replaces the groups selected for synchronization

  A full replacement, not an addition — the groups you send become the entire selection.
  Each entry carries an `id` and nothing else; Auth0 rejects any other key. Returns
  `:ok`, since Auth0 answers 204 with no body.

      iex> Auth0Client.Management.Connection.DirectoryProvisioning.replace_synchronized_groups(
      ...>   "some_conn_id",
      ...>   %{groups: [%{id: "03x8tuzt3mkl0ub"}]}
      ...> )
  """
  def replace_synchronized_groups(connection_id, body) do
    do_put("#{@path}/#{connection_id}/directory-provisioning/synchronized-groups", body)
  end
end
