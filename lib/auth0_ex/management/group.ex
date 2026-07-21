defmodule Auth0Ex.Management.Group do
  @moduledoc """
  A module representing group resource.

  Groups carry roles, and a user in a group inherits them — which is why
  `Auth0Ex.Management.User.effective_role_source_groups/2` can name a group as the
  reason a user holds a role. This module is the other end of that answer.

  **Groups are not created through the Management API.** They come from the identity
  provider, selected by
  `Auth0Ex.Management.Connection.DirectoryProvisioning.replace_synchronized_groups/2`,
  so there is no `create/1` here. `delete/1` drops a synced group from the tenant.

  The role side of the same relationship is `Auth0Ex.Management.Role.groups/2`,
  `add_groups/2` and `remove_groups/2`.
  """
  use Auth0Ex.Api, for: :mgmt
  @path "groups"

  @doc """
  Gets all the groups

  Filters on `connection_id`, `name`, `external_id` and `search`. Supports offset
  pagination (`page`, `per_page`, `include_totals`) and checkpoint pagination
  (`from`, `take`).

      iex> Auth0Ex.Management.Group.all()
      iex> Auth0Ex.Management.Group.all(connection_id: "con_abc123")
      iex> Auth0Ex.Management.Group.all(%{search: "engineering", take: 50})
  """
  def all(params \\ %{}) when is_map(params) or is_list(params) do
    do_get(@path, params)
  end

  @doc """
  Gets a group

      iex> Auth0Ex.Management.Group.get("grp_abc123")
  """
  def get(id) when is_binary(id) do
    do_get("#{@path}/#{id}")
  end

  @doc """
  Deletes a group

  Removes it from the tenant. If the connection still synchronizes it, the next run
  brings it back — stop selecting it with
  `Auth0Ex.Management.Connection.DirectoryProvisioning.replace_synchronized_groups/2`
  first.

      iex> Auth0Ex.Management.Group.delete("grp_abc123")
  """
  def delete(id) when is_binary(id) do
    do_delete("#{@path}/#{id}")
  end

  @doc """
  Lists the users in a group

  Uses checkpoint pagination — `from` and `take`.

      iex> Auth0Ex.Management.Group.members("grp_abc123")
      iex> Auth0Ex.Management.Group.members("grp_abc123", take: 50)
  """
  def members(id, params \\ %{}) when is_binary(id) do
    do_get("#{@path}/#{id}/members", params)
  end

  @doc """
  Lists the roles assigned to a group

  Every member of the group inherits these. The mirror of
  `Auth0Ex.Management.Role.groups/2`.

  Uses checkpoint pagination — `from` and `take`.

      iex> Auth0Ex.Management.Group.roles("grp_abc123")
  """
  def roles(id, params \\ %{}) when is_binary(id) do
    do_get("#{@path}/#{id}/roles", params)
  end

  @doc """
  Assigns roles to a group

  Grants them to every current and future member. Returns `:ok`; Auth0 answers 204
  with no body.

      iex> Auth0Ex.Management.Group.add_roles("grp_abc123", ["rol_1", "rol_2"])
  """
  def add_roles(id, role_ids) when is_binary(id) and is_list(role_ids) do
    do_post("#{@path}/#{id}/roles", %{roles: role_ids})
  end

  @doc """
  Removes roles from a group

  Sends the role ids in the body of the DELETE, which is what Auth0 documents.

      iex> Auth0Ex.Management.Group.remove_roles("grp_abc123", ["rol_1"])
  """
  def remove_roles(id, role_ids) when is_binary(id) and is_list(role_ids) do
    do_delete_body("#{@path}/#{id}/roles", %{roles: role_ids})
  end
end
