# Connections and provisioning

Connections are the identity providers your users authenticate against — a database, Google, an enterprise
SAML or OIDC provider, an AD/LDAP directory. This guide covers creating them, deciding which applications
may use them, and the two ways users get synchronized between Auth0 and an external directory.

Assumes Management API credentials are configured — see [Configuration](configuration.md).

Auth0 reference: [Connections](https://auth0.com/docs/api/management/v2/connections).

## The basics

```elixir
alias Auth0Client.Management.Connection

Connection.all(strategy: "auth0")
Connection.get("con_abc123")
Connection.create(%{name: "my-db", strategy: "auth0"})
Connection.update("con_abc123", %{display_name: "Staff login"})
Connection.delete("con_abc123")
```

`name` and `strategy` are fixed at creation — to rename a connection you recreate it. Past 1,000
connections, offset pagination stops working; pass `from` and `take` instead.

> #### `options` is replaced wholesale {: .warning}
>
> `update/2` overwrites the entire `options` object rather than merging into it. Read the connection
> first, change the one key, and send the whole thing back.

## Choosing which applications may use a connection

Two ways to express the same thing, and they behave very differently:

```elixir
# changes only the clients you name — the safe one
Connection.update_clients("con_abc123", [
  %{client_id: "abc123", status: true},
  %{client_id: "def456", status: false}
])

# the mirror: which connections one application can use
Auth0Client.Management.Client.connections("abc123")
```

Setting `enabled_clients` through `update/2` replaces the whole list, so it silently drops any application
someone else enabled between your read and your write. `update_clients/2` names one application at a time
and has no such race. Prefer it. Auth0 accepts at most 50 entries per call.

`Connection.clients/2` reads the same relationship from the connection's side. Both use checkpoint
pagination — omit `from` on the first call, then pass the `next` value the response gives you.

## Checking an AD/LDAP connection

```elixir
case Connection.status("con_abc123") do
  {:ok, _} -> :online
  {:error, %Auth0Client.Error{status: 404}} -> :offline
  {:error, error} -> {:error, error}
end
```

A 404 here means the connector is **offline**, not that the connection is missing — that is how Auth0
reports it, so it arrives as an error like any other 404. See [Error handling](error-handling.md).

## Provisioning users: two directions

Auth0 offers two separate features, and which one you want depends on who pushes:

| | Who initiates | Module |
|---|---|---|
| **SCIM** | the identity provider pushes users into Auth0 | `Connection.Scim` |
| **Directory provisioning** | Auth0 pulls users and groups out of the directory | `Connection.DirectoryProvisioning` |

Both attach to a connection, and a connection has at most one of each — so every function below takes a
**connection id**, never a configuration id.

### SCIM — inbound

The provider authenticates with a token you issue:

```elixir
alias Auth0Client.Management.Connection.Scim

# start from Auth0's defaults if you don't need a custom mapping
Scim.default_mapping("con_abc123")

Scim.create("con_abc123", %{
  user_id_attribute: "externalId",
  mapping: [%{auth0: "email", scim: "userName"}]
})

{:ok, token} = Scim.create_token("con_abc123", %{
  scopes: ["get:users", "post:users"],
  token_lifetime: 86_400
})
```

> #### The token value is shown once {: .warning}
>
> `create_token/2` is the only call that returns the secret. `tokens/1` lists the tokens that exist but not
> their values — if you lose one, delete it and issue another.

`token_lifetime` is in seconds and must be greater than 900. `update/2` is a PATCH but requires **both**
`user_id_attribute` and `mapping`, so send the whole configuration rather than the part you are changing.

```elixir
Scim.tokens("con_abc123")
Scim.delete_token("con_abc123", token_id)
Scim.delete("con_abc123")
```

### Directory provisioning — outbound

```elixir
alias Auth0Client.Management.Connection.DirectoryProvisioning, as: DP

DP.create("con_abc123", %{
  mapping: [%{auth0: "email", idp: "mail"}],
  synchronize_automatically: true,
  synchronize_groups: "selected"
})

# under "selected", name the groups — this replaces the whole selection
DP.replace_synchronized_groups("con_abc123", %{groups: [%{id: "03x8tuzt3mkl0ub"}]})

# run one now, regardless of synchronize_automatically
DP.synchronize("con_abc123")
```

`synchronize_groups` is `"all"`, `"off"` or `"selected"`. Switching it to `"selected"` does not narrow
anything by itself — until `replace_synchronized_groups/2` names groups, the selection is empty. Each entry
carries an `id` and nothing else; Auth0 rejects any other key.

`synchronize/1` returns once the run is *accepted*, not once it finishes. Read `synchronized_groups/2` or
the configuration itself to see the result.

Synced groups land in the tenant as `Auth0Client.Management.Group`, where they carry roles — which is why that
module has no `create/1`. See [Roles and permissions](rbac.md).

Both modules also list every configuration in the tenant, which is the quickest way to find out what is
already wired up:

```elixir
Scim.all()
DP.all()
```

## Connection keys

Okta and OIDC connections can authenticate to the upstream provider with Private Key JWT instead of a
shared secret:

```elixir
Connection.keys("con_abc123")
Connection.create_keys("con_abc123", %{signing_alg: "RS256"})
Connection.rotate_keys("con_abc123")
```

Create the keys *before* configuring the connection to use Private Key JWT — that ordering is what makes
the switch zero-downtime. This is the connection-side counterpart to the application-side credentials in
[Applications](applications.md); the two are separate mechanisms and do not share keys.

## Deleting a connection's users

```elixir
Connection.delete_conn_user("con_abc123", "someone@example.com")
```

Database connections only, and one user at a time — there is no endpoint for clearing a connection.
Deleting a connection with many users is asynchronous, and recreating one with the same name before that
finishes fails.
