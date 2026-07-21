# Roles and permissions

Granting access with Auth0's role-based access control, and working out where a user's access came from.
For roles scoped to a single customer organization, see [Organizations](organizations.md).

Assumes Management API credentials are configured — see [Configuration](configuration.md).

Auth0 reference: [Roles](https://auth0.com/docs/api/management/v2/roles),
[Users](https://auth0.com/docs/api/management/v2/users).

## Creating a role and granting it

```elixir
alias Auth0Ex.Management.{Role, User}

{:ok, role} = Role.create(%{name: "editor", description: "Can edit content"})

Role.add_permissions(role["id"], [
  {"https://api.example.com", "read:content"},
  {"https://api.example.com", "write:content"}
])
#=> :ok

User.assign_roles("auth0|abc123", [role["id"]])
#=> :ok
```

Permissions take `{api_identifier, permission_name}` tuples, or the map form Auth0 documents — both send
the same request:

```elixir
Role.add_permissions(role["id"], [
  %{resource_server_identifier: "https://api.example.com", permission_name: "read:content"}
])
```

String-keyed maps work too, so a permission read back from `Role.permissions/2` can be passed straight
into `Role.remove_permissions/2`.

The API identifier is the one you gave the API in Auth0, not its URL — check
`Auth0Ex.Management.ResourceServer.all/0` if you are unsure.

## Assigning directly to a user

Roles are the usual route, but a permission can be granted to one user without a role:

```elixir
User.assign_permissions("auth0|abc123", [{"https://api.example.com", "read:content"}])
User.permissions("auth0|abc123")
User.remove_permissions("auth0|abc123", [{"https://api.example.com", "read:content"}])
```

## Why does this user have this access?

`User.roles/2` and `User.permissions/2` report **direct assignments only**, so a user who inherits
everything through a group looks empty to them. The `effective_*` functions resolve the full picture:

```elixir
User.effective_roles("auth0|abc123")
User.effective_permissions("auth0|abc123", resource_server_identifier: "https://api.example.com")

# which role grants this permission?
User.effective_permission_source_roles("auth0|abc123",
  resource_server_identifier: "https://api.example.com",
  permission_name: "write:content"
)

# which group grants this role?
User.effective_role_source_groups("auth0|abc123", role_id: role["id"])
```

## Groups

A group carries roles, and every member inherits them. That is how a user ends up with a role nobody
assigned them directly — the answer `effective_role_source_groups/2` gives you.

```elixir
alias Auth0Ex.Management.Group

Group.all(connection_id: "con_abc123")
Group.get("grp_abc123")
Group.members("grp_abc123")
Group.roles("grp_abc123")                  # what every member inherits

Group.add_roles("grp_abc123", ["rol_1"])
Group.remove_roles("grp_abc123", ["rol_1"])
```

There is no `Group.create/1`. **Groups come from the identity provider**, selected with
`Auth0Ex.Management.Connection.DirectoryProvisioning.replace_synchronized_groups/2` — see
[Connections](connections.md). `Group.delete/1` drops one from the tenant, but if the connection still
synchronizes it, the next run brings it back.

The same relationship reads from the role's side too:

```elixir
Role.groups("rol_abc123")
Role.add_groups("rol_abc123", ["grp_abc123"])
```

Auth0 reference: [Groups](https://auth0.com/docs/api/management/v2/groups).

## Return values

Mutations return a bare `:ok`. Auth0 answers them with 200, 201 or 204 depending on the endpoint, all with
an empty body; this library treats those as the one outcome they are. See
[Error handling](error-handling.md) for the full set of return shapes.
