defmodule Auth0Ex.Management.Role do
  @moduledoc """
  A module representing roles on Auth0.

  A role is a named bundle of permissions. Grant it to a user with
  `Auth0Ex.Management.User.assign_roles/2`; there is no endpoint for removing a
  user from a role on this side, so use `Auth0Ex.Management.User.remove_roles/2`.

  https://auth0.com/docs/api/management/v2/roles
  """

  use Auth0Ex.Api, for: :mgmt
  @path "roles"

  @doc """
  Gets all the roles

  Supports `name_filter` to search by name, and `page` / `per_page` /
  `include_totals` for pagination.

      iex> Auth0Ex.Management.Role.all()
      iex> Auth0Ex.Management.Role.all(name_filter: "admin", per_page: 50)
  """
  def all(params \\ %{}) when is_map(params) or is_list(params) do
    do_get(@path, params)
  end

  @doc """
  Gets a single role

      iex> Auth0Ex.Management.Role.get("rol_abc123")
  """
  def get(id) when is_binary(id), do: do_get("#{@path}/#{id}", %{})

  @doc """
  Creates a role. `name` is required; `description` is optional.

      iex> Auth0Ex.Management.Role.create(%{name: "admin", description: "Can do anything"})
  """
  def create(body), do: do_post(@path, body)

  @doc """
  Updates a role's name or description

      iex> Auth0Ex.Management.Role.update("rol_abc123", %{description: "Updated"})
  """
  def update(id, body) when is_binary(id), do: do_patch("#{@path}/#{id}", body)

  @doc """
  Deletes a role. Users assigned to it lose the permissions it granted.

      iex> Auth0Ex.Management.Role.delete("rol_abc123")
  """
  def delete(id) when is_binary(id), do: do_delete("#{@path}/#{id}")

  @doc """
  Gets the permissions a role grants

      iex> Auth0Ex.Management.Role.permissions("rol_abc123")
      iex> Auth0Ex.Management.Role.permissions("rol_abc123", per_page: 50)
  """
  def permissions(id, params \\ %{}) when is_binary(id) do
    do_get("#{@path}/#{id}/permissions", params)
  end

  @doc """
  Adds permissions to a role.

  Accepts either the documented map form or `{api_identifier, permission_name}`
  tuples.

      iex> Auth0Ex.Management.Role.add_permissions("rol_abc123", [{"https://api.example.com", "read:users"}])
      iex> Auth0Ex.Management.Role.add_permissions("rol_abc123", [%{resource_server_identifier: "https://api.example.com", permission_name: "read:users"}])
  """
  def add_permissions(id, permissions) when is_binary(id) and is_list(permissions) do
    do_post("#{@path}/#{id}/permissions", %{permissions: normalize_permissions(permissions)})
  end

  @doc """
  Removes permissions from a role

      iex> Auth0Ex.Management.Role.remove_permissions("rol_abc123", [{"https://api.example.com", "read:users"}])
  """
  def remove_permissions(id, permissions) when is_binary(id) and is_list(permissions) do
    do_delete_body("#{@path}/#{id}/permissions", %{
      permissions: normalize_permissions(permissions)
    })
  end

  @doc """
  Gets the users assigned to a role.

  Supports offset pagination (`page` / `per_page`) and checkpoint pagination
  (`from` / `take`). Auth0 requires checkpoint pagination past 1000 records.

      iex> Auth0Ex.Management.Role.users("rol_abc123")
      iex> Auth0Ex.Management.Role.users("rol_abc123", take: 50)
  """
  def users(id, params \\ %{}) when is_binary(id) do
    do_get("#{@path}/#{id}/users", params)
  end

  @doc """
  Assigns users to a role

      iex> Auth0Ex.Management.Role.add_users("rol_abc123", ["auth0|user1", "auth0|user2"])
  """
  def add_users(id, user_ids) when is_binary(id) and is_list(user_ids) do
    do_post("#{@path}/#{id}/users", %{users: user_ids})
  end

  @doc """
  Gets the groups a role is assigned to.

  Uses checkpoint pagination only — `from` and `take`.

      iex> Auth0Ex.Management.Role.groups("rol_abc123")
  """
  def groups(id, params \\ %{}) when is_binary(id) do
    do_get("#{@path}/#{id}/groups", params)
  end

  @doc """
  Assigns groups to a role

      iex> Auth0Ex.Management.Role.add_groups("rol_abc123", ["grp_1", "grp_2"])
  """
  def add_groups(id, group_ids) when is_binary(id) and is_list(group_ids) do
    do_post("#{@path}/#{id}/groups", %{groups: group_ids})
  end

  @doc """
  Removes groups from a role

      iex> Auth0Ex.Management.Role.remove_groups("rol_abc123", ["grp_1"])
  """
  def remove_groups(id, group_ids) when is_binary(id) and is_list(group_ids) do
    do_delete_body("#{@path}/#{id}/groups", %{groups: group_ids})
  end
end
