defmodule Auth0Client.Management.Organization do
  @moduledoc """
  A module representing organizations on Auth0.

  Organizations are Auth0's B2B primitive: a tenant hosts many organizations, each
  with its own members, connections and branding. Roles assigned through
  `assign_member_roles/3` are scoped to that organization, so the same user can be
  an admin of one and a read-only member of another — which is the part of Auth0
  RBAC most often misread.

  Auth0 exposes two overlapping connection APIs here. This module implements
  `/connections`, whose payload is a superset of the older `/enabled_connections`;
  the latter is deliberately not wrapped.

  https://auth0.com/docs/api/management/v2/organizations
  """

  use Auth0Client.Api, for: :mgmt
  @path "organizations"

  @doc """
  Gets all organizations.

  Supports offset pagination (`page` / `per_page` / `include_totals`), checkpoint
  pagination (`from` / `take`), and `sort`.

      iex> Auth0Client.Management.Organization.all()
      iex> Auth0Client.Management.Organization.all(take: 50, sort: "name:1")
  """
  def all(params \\ %{}) when is_map(params) or is_list(params) do
    do_get(@path, params)
  end

  @doc """
  Gets a single organization by id

      iex> Auth0Client.Management.Organization.get("org_abc123")
  """
  def get(id) when is_binary(id), do: do_get("#{@path}/#{id}")

  @doc """
  Gets a single organization by name.

  The name is the lowercase, space-free identifier, not `display_name`.

      iex> Auth0Client.Management.Organization.get_by_name("acme-corp")
  """
  def get_by_name(name) when is_binary(name), do: do_get("#{@path}/name/#{name}")

  @doc """
  Creates an organization. `name` is required, and must be lowercase with no spaces.

      iex> Auth0Client.Management.Organization.create(%{name: "acme-corp", display_name: "Acme Corp"})
  """
  def create(body), do: do_post(@path, body)

  @doc """
  Updates an organization

      iex> Auth0Client.Management.Organization.update("org_abc123", %{display_name: "Acme Corporation"})
  """
  def update(id, body) when is_binary(id), do: do_patch("#{@path}/#{id}", body)

  @doc """
  Deletes an organization

      iex> Auth0Client.Management.Organization.delete("org_abc123")
  """
  def delete(id) when is_binary(id), do: do_delete("#{@path}/#{id}")

  @doc """
  Gets an organization's members.

  Supports offset and checkpoint pagination, plus `fields` / `include_fields`.

      iex> Auth0Client.Management.Organization.members("org_abc123")
      iex> Auth0Client.Management.Organization.members("org_abc123", take: 50)
  """
  def members(id, params \\ %{}) when is_binary(id) do
    do_get("#{@path}/#{id}/members", params)
  end

  @doc """
  Adds users to an organization. They must already exist in the tenant.

      iex> Auth0Client.Management.Organization.add_members("org_abc123", ["auth0|user1"])
  """
  def add_members(id, user_ids) when is_binary(id) and is_list(user_ids) do
    do_post("#{@path}/#{id}/members", %{members: user_ids})
  end

  @doc """
  Removes users from an organization. The users themselves are not deleted.

      iex> Auth0Client.Management.Organization.remove_members("org_abc123", ["auth0|user1"])
  """
  def remove_members(id, user_ids) when is_binary(id) and is_list(user_ids) do
    do_delete_body("#{@path}/#{id}/members", %{members: user_ids})
  end

  @doc """
  Gets the roles a member holds *within this organization*.

  Not to be confused with `role_members/3`, which goes the other way — the members
  holding a given role.

      iex> Auth0Client.Management.Organization.member_roles("org_abc123", "auth0|user1")
  """
  def member_roles(id, user_id, params \\ %{}) when is_binary(id) and is_binary(user_id) do
    do_get("#{@path}/#{id}/members/#{user_id}/roles", params)
  end

  @doc """
  Assigns roles to a member, scoped to this organization

      iex> Auth0Client.Management.Organization.assign_member_roles("org_abc123", "auth0|user1", ["rol_1"])
  """
  def assign_member_roles(id, user_id, role_ids)
      when is_binary(id) and is_binary(user_id) and is_list(role_ids) do
    do_post("#{@path}/#{id}/members/#{user_id}/roles", %{roles: role_ids})
  end

  @doc """
  Removes roles from a member of this organization

      iex> Auth0Client.Management.Organization.remove_member_roles("org_abc123", "auth0|user1", ["rol_1"])
  """
  def remove_member_roles(id, user_id, role_ids)
      when is_binary(id) and is_binary(user_id) and is_list(role_ids) do
    do_delete_body("#{@path}/#{id}/members/#{user_id}/roles", %{roles: role_ids})
  end

  @doc """
  Gets every role a member holds in this organization, including roles inherited
  through a group.

  `member_roles/3` reports only direct assignments. Uses checkpoint pagination.

      iex> Auth0Client.Management.Organization.member_effective_roles("org_abc123", "auth0|user1")
  """
  def member_effective_roles(id, user_id, params \\ %{})
      when is_binary(id) and is_binary(user_id) do
    do_get("#{@path}/#{id}/members/#{user_id}/effective-roles", params)
  end

  @doc """
  Gets the groups that grant a member a role in this organization, answering "why
  does this member have this role?".

  Pass `role_id` to narrow it to one role.

      iex> Auth0Client.Management.Organization.member_effective_role_source_groups("org_abc123", "auth0|user1", role_id: "rol_1")
  """
  def member_effective_role_source_groups(id, user_id, params \\ %{})
      when is_binary(id) and is_binary(user_id) do
    do_get("#{@path}/#{id}/members/#{user_id}/effective-roles/sources/groups", params)
  end

  @doc """
  Gets the members holding a given role in this organization.

  The inverse of `member_roles/3`. Uses checkpoint pagination.

      iex> Auth0Client.Management.Organization.role_members("org_abc123", "rol_1")
  """
  def role_members(id, role_id, params \\ %{}) when is_binary(id) and is_binary(role_id) do
    do_get("#{@path}/#{id}/roles/#{role_id}/members", params)
  end

  @doc """
  Gets an organization's pending invitations

      iex> Auth0Client.Management.Organization.invitations("org_abc123")
  """
  def invitations(id, params \\ %{}) when is_binary(id) do
    do_get("#{@path}/#{id}/invitations", params)
  end

  @doc """
  Gets a single invitation

      iex> Auth0Client.Management.Organization.invitation("org_abc123", "inv_1")
  """
  def invitation(id, invitation_id, params \\ %{})
      when is_binary(id) and is_binary(invitation_id) do
    do_get("#{@path}/#{id}/invitations/#{invitation_id}", params)
  end

  @doc """
  Creates an invitation.

  `inviter` (with a `name`), `invitee` (with an `email`) and `client_id` are all
  required. Unlike most mutations here, this returns the created invitation rather
  than a bare `:ok`.

      iex> Auth0Client.Management.Organization.create_invitation("org_abc123", %{
      ...>   inviter: %{name: "Admin"},
      ...>   invitee: %{email: "new@example.com"},
      ...>   client_id: "a_client_id"
      ...> })
  """
  def create_invitation(id, body) when is_binary(id) do
    do_post("#{@path}/#{id}/invitations", body)
  end

  @doc """
  Revokes a pending invitation

      iex> Auth0Client.Management.Organization.delete_invitation("org_abc123", "inv_1")
  """
  def delete_invitation(id, invitation_id) when is_binary(id) and is_binary(invitation_id) do
    do_delete("#{@path}/#{id}/invitations/#{invitation_id}")
  end

  @doc """
  Gets the connections enabled for an organization.

  Pass `is_enabled` to filter.

      iex> Auth0Client.Management.Organization.connections("org_abc123")
  """
  def connections(id, params \\ %{}) when is_binary(id) do
    do_get("#{@path}/#{id}/connections", params)
  end

  @doc """
  Gets a single connection as enabled for this organization

      iex> Auth0Client.Management.Organization.connection("org_abc123", "con_1")
  """
  def connection(id, connection_id) when is_binary(id) and is_binary(connection_id) do
    do_get("#{@path}/#{id}/connections/#{connection_id}")
  end

  @doc """
  Enables a connection for an organization. `connection_id` is required, and the
  connection must already exist in the tenant.

      iex> Auth0Client.Management.Organization.add_connection("org_abc123", %{connection_id: "con_1", assign_membership_on_login: true})
  """
  def add_connection(id, body) when is_binary(id) do
    do_post("#{@path}/#{id}/connections", body)
  end

  @doc """
  Updates how a connection behaves for this organization

      iex> Auth0Client.Management.Organization.update_connection("org_abc123", "con_1", %{show_as_button: false})
  """
  def update_connection(id, connection_id, body)
      when is_binary(id) and is_binary(connection_id) do
    do_patch("#{@path}/#{id}/connections/#{connection_id}", body)
  end

  @doc """
  Disables a connection for this organization. The connection itself is not deleted.

      iex> Auth0Client.Management.Organization.remove_connection("org_abc123", "con_1")
  """
  def remove_connection(id, connection_id) when is_binary(id) and is_binary(connection_id) do
    do_delete("#{@path}/#{id}/connections/#{connection_id}")
  end

  @doc """
  Gets the client grants associated with an organization

      iex> Auth0Client.Management.Organization.client_grants("org_abc123")
      iex> Auth0Client.Management.Organization.client_grants("org_abc123", audience: "https://api.example.com")
  """
  def client_grants(id, params \\ %{}) when is_binary(id) do
    do_get("#{@path}/#{id}/client-grants", params)
  end

  @doc """
  Associates an existing client grant with an organization

      iex> Auth0Client.Management.Organization.add_client_grant("org_abc123", "cgr_1")
  """
  def add_client_grant(id, grant_id) when is_binary(id) and is_binary(grant_id) do
    do_post("#{@path}/#{id}/client-grants", %{grant_id: grant_id})
  end

  @doc """
  Removes a client grant from an organization

      iex> Auth0Client.Management.Organization.remove_client_grant("org_abc123", "cgr_1")
  """
  def remove_client_grant(id, grant_id) when is_binary(id) and is_binary(grant_id) do
    do_delete("#{@path}/#{id}/client-grants/#{grant_id}")
  end

  @doc """
  Gets an organization's discovery domains.

  Discovery domains route a user to an organization by their email domain — Home
  Realm Discovery. Uses checkpoint pagination.

      iex> Auth0Client.Management.Organization.discovery_domains("org_abc123")
  """
  def discovery_domains(id, params \\ %{}) when is_binary(id) do
    do_get("#{@path}/#{id}/discovery-domains", params)
  end

  @doc """
  Gets a discovery domain by id

      iex> Auth0Client.Management.Organization.discovery_domain("org_abc123", "dom_1")
  """
  def discovery_domain(id, discovery_domain_id)
      when is_binary(id) and is_binary(discovery_domain_id) do
    do_get("#{@path}/#{id}/discovery-domains/#{discovery_domain_id}")
  end

  @doc """
  Gets a discovery domain by the domain itself

      iex> Auth0Client.Management.Organization.discovery_domain_by_name("org_abc123", "acme.com")
  """
  def discovery_domain_by_name(id, domain) when is_binary(id) and is_binary(domain) do
    do_get("#{@path}/#{id}/discovery-domains/name/#{domain}")
  end

  @doc """
  Adds a discovery domain to an organization. `domain` is required.

      iex> Auth0Client.Management.Organization.add_discovery_domain("org_abc123", %{domain: "acme.com"})
  """
  def add_discovery_domain(id, body) when is_binary(id) do
    do_post("#{@path}/#{id}/discovery-domains", body)
  end

  @doc """
  Updates a discovery domain

      iex> Auth0Client.Management.Organization.update_discovery_domain("org_abc123", "dom_1", %{use_for_organization_discovery: true})
  """
  def update_discovery_domain(id, discovery_domain_id, body)
      when is_binary(id) and is_binary(discovery_domain_id) do
    do_patch("#{@path}/#{id}/discovery-domains/#{discovery_domain_id}", body)
  end

  @doc """
  Removes a discovery domain from an organization

      iex> Auth0Client.Management.Organization.remove_discovery_domain("org_abc123", "dom_1")
  """
  def remove_discovery_domain(id, discovery_domain_id)
      when is_binary(id) and is_binary(discovery_domain_id) do
    do_delete("#{@path}/#{id}/discovery-domains/#{discovery_domain_id}")
  end

  @doc """
  Gets the groups assigned to an organization. Uses checkpoint pagination.

      iex> Auth0Client.Management.Organization.groups("org_abc123")
  """
  def groups(id, params \\ %{}) when is_binary(id) do
    do_get("#{@path}/#{id}/groups", params)
  end

  @doc """
  Gets the roles a group grants within this organization

      iex> Auth0Client.Management.Organization.group_roles("org_abc123", "grp_1")
  """
  def group_roles(id, group_id, params \\ %{}) when is_binary(id) and is_binary(group_id) do
    do_get("#{@path}/#{id}/groups/#{group_id}/roles", params)
  end

  @doc """
  Assigns roles to a group within this organization

      iex> Auth0Client.Management.Organization.assign_group_roles("org_abc123", "grp_1", ["rol_1"])
  """
  def assign_group_roles(id, group_id, role_ids)
      when is_binary(id) and is_binary(group_id) and is_list(role_ids) do
    do_post("#{@path}/#{id}/groups/#{group_id}/roles", %{roles: role_ids})
  end

  @doc """
  Removes roles from a group within this organization

      iex> Auth0Client.Management.Organization.remove_group_roles("org_abc123", "grp_1", ["rol_1"])
  """
  def remove_group_roles(id, group_id, role_ids)
      when is_binary(id) and is_binary(group_id) and is_list(role_ids) do
    do_delete_body("#{@path}/#{id}/groups/#{group_id}/roles", %{roles: role_ids})
  end
end
