# Organizations

Auth0's B2B primitive: one tenant hosting many customer organizations, each with its own members,
connections and branding.

Assumes you are comfortable with [roles and permissions](rbac.md), since organization roles build on them.

Auth0 reference: [Organizations](https://auth0.com/docs/api/management/v2/organizations).

## Creating one and adding members

```elixir
alias Auth0Client.Management.Organization

# `name` must be lowercase with no spaces; display_name is the human-facing one
{:ok, org} = Organization.create(%{name: "acme-corp", display_name: "Acme Corp"})

Organization.add_members(org["id"], ["auth0|abc123"])
#=> :ok
```

Members must already exist as users in the tenant; adding a member does not create one.

## Organization-scoped roles

```elixir
Organization.assign_member_roles(org["id"], "auth0|abc123", [role["id"]])
#=> :ok

Organization.member_roles(org["id"], "auth0|abc123")
```

> #### These roles apply inside one organization only {: .tip}
>
> The same user can be an admin of one organization and a read-only member of another.
> `Organization.member_roles/3` reports a member's roles inside one organization;
> `Auth0Client.Management.User.roles/2` reports roles assigned tenant-wide. They are different grants.

As with tenant-wide RBAC, `member_effective_roles/3` resolves roles inherited through groups, and
`member_effective_role_source_groups/3` says which group granted one.

`role_members/3` goes the other way — the members holding a given role in this organization. It reads
almost the same as `member_roles/3` and is the inverse of it.

## Invitations

```elixir
Organization.create_invitation(org["id"], %{
  inviter: %{name: "Admin"},
  invitee: %{email: "new@acme.com"},
  client_id: client_id
})
#=> {:ok, %{"invitation_url" => "https://your-tenant.auth0.com/..."}}
```

Unlike most mutations here, this returns the created invitation rather than a bare `:ok` — the
`invitation_url` is the point of the call. Send it to the invitee, or let Auth0 email it.

`invitations/2` lists the pending ones; `delete_invitation/2` revokes one.

## Connections

Which identity providers an organization's members can log in with:

```elixir
Organization.connections(org["id"])

Organization.add_connection(org["id"], %{
  connection_id: "con_abc123",
  assign_membership_on_login: true
})
```

The connection must already exist in the tenant — see `Auth0Client.Management.Connection`.
`assign_membership_on_login: true` adds users to the organization automatically the first time they log in
through it.

## Discovery domains

Home Realm Discovery: route a user to an organization by their email domain, so they never pick from a
list.

```elixir
Organization.add_discovery_domain(org["id"], %{domain: "acme.com"})
Organization.discovery_domains(org["id"])
```
