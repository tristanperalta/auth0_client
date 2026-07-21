defmodule Auth0Ex.Management.User do
  @moduledoc """
  A module representing users on Auth0
  """

  use Auth0Ex.Api, for: :mgmt
  @path "users"

  @doc """
  Gets all the users

  Defaults to the v3 search engine, which is the only one Auth0 still supports. Pass
  an explicit `search_engine` to override it.

      iex> Auth0Ex.Management.User.all()
      iex> Auth0Ex.Management.User.all(fields: "name", q: "app_metadata.admin:'true'")
  """
  def all(params \\ %{}) when is_map(params) or is_list(params) do
    params
    |> Enum.into(%{})
    |> Map.put_new(:search_engine, "v3")
    |> then(&do_get(@path, &1))
  end

  @doc """
  Gets a specific user record with a given user id

      iex> Auth0Ex.Management.User.get("auth0|some_user_id")
      iex> Auth0Ex.Management.User.get("auth0|some_user_id", %{fields: "email,name,username"})
  """
  def get(user_id, params \\ %{}) when is_binary(user_id) and is_map(params) do
    do_get("#{@path}/#{user_id}", params)
  end

  @doc """
  Creates a user for the specified connection

      iex> Auth0Ex.Management.User.create("test_connection", %{email: "test.user@email.com", username: "test_user_name"})
  """
  def create(connection, body \\ %{}) when is_binary(connection) and is_map(body) do
    do_post(@path, Map.put(body, :connection, connection))
  end

  @doc """
  Updates a user's information given a user id

      iex> Auth0Ex.Management.User.update("auth0|some_user_id", %{app_metadata: %{admin: false}})
  """
  def update(user_id, body \\ %{}) when is_binary(user_id) and is_map(body) do
    do_patch("#{@path}/#{user_id}", body)
  end

  @doc """
  Deletes a user with a give user id

      iex> Auth0Ex.Management.User.delete("auth0|some_user_id")
  """
  def delete(user_id) when is_binary(user_id) do
    do_delete("#{@path}/#{user_id}")
  end

  @doc """
  Get a user's log

      iex> Auth0Ex.Management.User.log("auth0|233423")
      iex> Auth0Ex.Management.User.log("auth0|23423", page: 2, per_page: 10)
  """
  def log(user_id, params) do
    do_get("#{@path}/#{user_id}/logs", params)
  end

  @doc """
  Get all Guardain enrollments for given user_id

      iex> Auth0Ex.Management.User.enrollments("auth0|234")
  """
  def enrollments(user_id), do: do_get("#{@path}/#{user_id}/enrollments", %{})

  @doc """
  Deletes a user's multifactor provider

      iex> Auth0Ex.Management.User.delete_mfprovider("auth0|23423", "duo")
  """
  def delete_mfprovider(user_id, provider) do
    do_delete("#{@path}/#{user_id}/multifactor/#{provider}")
  end

  @doc """
  Unlinks an identity from the target user, and it becomes a separated user again.

      iex> Auth0Ex.Management.User.unlink("some_user_id", "github", "23984234")
  """
  def unlink(primary_id, provider, secondary_id) do
    do_delete("#{@path}/#{primary_id}/identities/#{provider}/#{secondary_id}")
  end

  @doc """
  Removes current Guardain recovery code and generates new one

      iex> Auth0Ex.Management.User.regenerate_recovery_code("auth0|34234")
  """
  def regenerate_recovery_code(id) do
    do_post("#{@path}/#{id}/recovery-code-regeneration")
  end

  @doc """
  Links the account specified in the body to the given user_id param

      iex> Auth0Ex.Management.User.link("some_user_id", link_with: "secondary_acc_jwt")
      iex> Auth0Ex.Management.User.link("some_user_id", provider: "github", user_id: "23423", connection_id: "som")
  """
  def link(id, body) do
    do_post("#{@path}/#{id}/identities", body)
  end

  @doc """
    List the roles associated with a user. Scopes: read:users read:roles

      iex > Auth0Ex.Management.User.roles("auth0|23423")
  """
  def roles(user_id, params \\ %{}) do
    do_get("#{@path}/#{user_id}/roles", params)
  end

  @doc """
  Assigns roles to a user. Scopes: update:users

      iex> Auth0Ex.Management.User.assign_roles("auth0|23423", ["rol_abc123"])
  """
  def assign_roles(user_id, role_ids) when is_binary(user_id) and is_list(role_ids) do
    do_post("#{@path}/#{user_id}/roles", %{roles: role_ids})
  end

  @doc """
  Removes roles from a user. Scopes: update:users

      iex> Auth0Ex.Management.User.remove_roles("auth0|23423", ["rol_abc123"])
  """
  def remove_roles(user_id, role_ids) when is_binary(user_id) and is_list(role_ids) do
    do_delete_body("#{@path}/#{user_id}/roles", %{roles: role_ids})
  end

  @doc """
  Lists the permissions granted to a user directly, ignoring any that come from a
  role. Use `effective_permissions/2` for the full picture. Scopes: read:users

      iex> Auth0Ex.Management.User.permissions("auth0|23423")
  """
  def permissions(user_id, params \\ %{}) when is_binary(user_id) do
    do_get("#{@path}/#{user_id}/permissions", params)
  end

  @doc """
  Assigns permissions to a user directly.

  Accepts either the documented map form or `{api_identifier, permission_name}`
  tuples. Scopes: update:users

      iex> Auth0Ex.Management.User.assign_permissions("auth0|23423", [{"https://api.example.com", "read:users"}])
  """
  def assign_permissions(user_id, permissions)
      when is_binary(user_id) and is_list(permissions) do
    do_post("#{@path}/#{user_id}/permissions", %{
      permissions: normalize_permissions(permissions)
    })
  end

  @doc """
  Removes permissions from a user. Scopes: update:users

      iex> Auth0Ex.Management.User.remove_permissions("auth0|23423", [{"https://api.example.com", "read:users"}])
  """
  def remove_permissions(user_id, permissions)
      when is_binary(user_id) and is_list(permissions) do
    do_delete_body("#{@path}/#{user_id}/permissions", %{
      permissions: normalize_permissions(permissions)
    })
  end

  @doc """
  Lists the organizations a user belongs to. Scopes: read:users read:organizations

      iex> Auth0Ex.Management.User.organizations("auth0|23423")
  """
  def organizations(user_id, params \\ %{}) when is_binary(user_id) do
    do_get("#{@path}/#{user_id}/organizations", params)
  end

  @doc """
  Lists every role a user has, whether assigned directly or inherited through a
  group.

  `roles/2` reports only direct assignments, so a user who gets their access
  through a group looks role-less to it. Use this when you need the truth.

  Uses checkpoint pagination — `from` and `take`. Scopes: read:users read:roles

      iex> Auth0Ex.Management.User.effective_roles("auth0|23423")
  """
  def effective_roles(user_id, params \\ %{}) when is_binary(user_id) do
    do_get("#{@path}/#{user_id}/effective-roles", params)
  end

  @doc """
  Lists the groups that grant a user a given role, answering "why does this user
  have this role?".

  Pass `role_id` to narrow it to one role.

      iex> Auth0Ex.Management.User.effective_role_source_groups("auth0|23423", role_id: "rol_abc123")
  """
  def effective_role_source_groups(user_id, params \\ %{}) when is_binary(user_id) do
    do_get("#{@path}/#{user_id}/effective-roles/sources/groups", params)
  end

  @doc """
  Lists every permission a user has, whether granted directly, through a role, or
  through a group.

  Pass `resource_server_identifier` to limit it to one API. Uses checkpoint
  pagination — `from` and `take`.

      iex> Auth0Ex.Management.User.effective_permissions("auth0|23423")
      iex> Auth0Ex.Management.User.effective_permissions("auth0|23423", resource_server_identifier: "https://api.example.com")
  """
  def effective_permissions(user_id, params \\ %{}) when is_binary(user_id) do
    do_get("#{@path}/#{user_id}/effective-permissions", params)
  end

  @doc """
  Lists the roles that grant a user a given permission, answering "why does this
  user have this permission?".

  Pass `resource_server_identifier` and `permission_name` to name the permission.

      iex> Auth0Ex.Management.User.effective_permission_source_roles("auth0|23423", resource_server_identifier: "https://api.example.com", permission_name: "read:users")
  """
  def effective_permission_source_roles(user_id, params \\ %{}) when is_binary(user_id) do
    do_get("#{@path}/#{user_id}/effective-permissions/sources/effective-roles", params)
  end

  @doc """
    Deletes all users MFA authentication methods. Scopes: delete:authentication_methods

      iex > Auth0Ex.Management.User.delete_authentication_methods("auth0|23423")
  """
  def delete_authentication_methods(user_id) do
    do_delete("#{@path}/#{user_id}/authentication-methods")
  end
end
