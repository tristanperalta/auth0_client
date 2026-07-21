# Auth0Ex

![Build Status](https://github.com/tristanperalta/auth0_client/actions/workflows/main.yml/badge.svg)

> An elixir client library for Auth0

This is a fork of [techgaun/auth0_ex](https://github.com/techgaun/auth0_ex). The repository is named
`auth0_client`, but the OTP application, module namespace and config key remain `:auth0_ex` /
`Auth0Ex` so the library stays drop-in compatible with the original.

## Installation

This fork is not published to hex. Depend on it from git:

```elixir
def deps do
  [{:auth0_ex, github: "tristanperalta/auth0_client"}]
end
```

The `auth0_ex` package on hex is the upstream project and does not contain this fork's changes.

## Configuration

You need a `domain`, plus credentials for the Management API if you use it.

The recommended setup is a non-interactive client, because `Auth0Ex` can then fetch a new `access_token`
whenever the current one expires. Create one as described in
[Auth0's docs](https://auth0.com/docs/api/management/v2/tokens), then take the client ID and secret from
its settings page:

```elixir
config :auth0_ex,
  domain: System.get_env("AUTH0_DOMAIN"),
  mgmt_client_id: System.get_env("AUTH0_MGMT_CLIENT_ID"),
  mgmt_client_secret: System.get_env("AUTH0_MGMT_CLIENT_SECRET"),
  http_opts: []
```

Tokens obtained this way are cached and renewed automatically. Only one fetch is ever in flight, so a
cold cache under load makes one request to Auth0 rather than one per caller, and a token is renewed shortly
before it expires — by `token_refresh_skew` seconds, 60 by default:

```elixir
config :auth0_ex, token_refresh_skew: 120
```

If Auth0 rejects a cached token with a 401 — a rotated secret, a revoked client — the token is discarded
and the request replayed once with a fresh one, so callers do not need their own retry.

Alternatively, supply a pre-created Management API token. It is used for every request as-is, and is never
refreshed or retried:

```elixir
config :auth0_ex,
  domain: System.get_env("AUTH0_DOMAIN"),
  mgmt_token: System.get_env("AUTH0_MGMT_TOKEN"),
  http_opts: []
```

Using only the Authentication API needs nothing but `domain`.

### Domains

`domain` is the whole tenant domain Auth0 gives you, including the region — `your-tenant.us.auth0.com`,
not `your-tenant`. A domain that does not end in `auth0.com` raises `ArgumentError`.

To use a custom domain, set `custom_domain: true` to skip that check:

```elixir
config :auth0_ex,
  domain: "auth.example.com",
  custom_domain: true
```

### HTTP options

`http_opts` is passed straight through to [Req](https://hexdocs.pm/req), which this library uses as its
HTTP client. Any [`Req.request/1` option](https://hexdocs.pm/req/Req.html#request/1) is valid there:

```elixir
config :auth0_ex,
  http_opts: [
    receive_timeout: 30_000,
    connect_options: [timeout: 10_000],
    retry: :safe_transient
  ]
```

Options are passed on unvalidated, so anything you set here — including options that weaken TLS — takes
effect as written.

## Usage

### Management API

Each resource is a module under `Auth0Ex.Management`. Tokens are fetched and cached for you.

```elixir
Auth0Ex.Management.User.all(%{q: "email:*@example.com"})
#=> {:ok, [%{"user_id" => "auth0|abc123", ...}]}

Auth0Ex.Management.User.get("auth0|abc123", %{fields: "email,name"})
#=> {:ok, %{"email" => "someone@example.com", "name" => "Someone"}}

Auth0Ex.Management.User.create("Username-Password-Authentication", %{
  email: "someone@example.com",
  password: "a-strong-password"
})

Auth0Ex.Management.User.update("auth0|abc123", %{app_metadata: %{admin: true}})

Auth0Ex.Management.User.delete("auth0|abc123")
#=> :ok

Auth0Ex.Management.Ticket.password_change(%{user_id: "auth0|abc123"})
#=> {:ok, %{"ticket" => "https://your-tenant.auth0.com/lo/reset?ticket=..."}}
```

Available resources: `Client`, `ClientGrant`, `Connection`, `DeviceCredential`, `EmailProvider`, `Job`,
`Log`, `ResourceServer`, `Role`, `Ticket`, `User`, `UserBlock`.

### Roles and permissions

```elixir
alias Auth0Ex.Management.{Role, User}

{:ok, role} = Role.create(%{name: "editor", description: "Can edit content"})

# Permissions take {api_identifier, permission_name} tuples, or the map form
# Auth0 documents — both send the same request
Role.add_permissions(role["id"], [
  {"https://api.example.com", "read:content"},
  {"https://api.example.com", "write:content"}
])
#=> :ok

User.assign_roles("auth0|abc123", [role["id"]])
#=> :ok
```

Mutations return a bare `:ok`. Auth0 answers them with 200, 201 or 204 depending on the endpoint, all with
an empty body; this library treats those as the one outcome they are.

To find out why a user has some access, use the effective-* functions. `User.roles/2` reports only direct
assignments, so a user who inherits everything through a group looks role-less to it:

```elixir
User.effective_roles("auth0|abc123")
User.effective_permissions("auth0|abc123", resource_server_identifier: "https://api.example.com")

# which role grants this permission?
User.effective_permission_source_roles("auth0|abc123",
  resource_server_identifier: "https://api.example.com",
  permission_name: "write:content"
)
```

### Logging a user in

`/authorize` and the logout endpoints are browser redirects, not API calls, so `Auth0Ex.Authentication.Url`
builds URLs for you to redirect to rather than requesting them itself.

```elixir
alias Auth0Ex.Authentication.{Token, Url}

# 1. send the browser to Auth0
Url.authorize(client_id, %{
  redirect_uri: "https://app.example.com/callback",
  scope: "openid profile email",
  state: state
})
#=> "https://your-tenant.auth0.com/authorize?client_id=…&response_type=code&…"

# 2. Auth0 redirects back with ?code=… — exchange it
Token.auth_code(client_id, client_secret, code, "https://app.example.com/callback")
#=> {:ok, %{"access_token" => …, "refresh_token" => …, "id_token" => …}}

# 3. later, swap the refresh token for a fresh access token
Token.refresh(client_id, refresh_token, %{client_secret: client_secret})

# 4. log out — again a redirect
Url.logout(%{returnTo: "https://app.example.com", client_id: client_id})
```

For a public client — a SPA or mobile app with no secret — use PKCE: pass `code_challenge` and
`code_challenge_method` to `authorize/2`, then `Token.auth_code_pkce(client_id, code, code_verifier)`.

Authenticating usernames and passwords directly is also possible, though a redirect to `/authorize` is
preferred. The grant must be enabled on the application in the Auth0 dashboard:

```elixir
Token.password(client_id, "user@example.com", password, %{
  realm: "Username-Password-Authentication",
  forwarded_for: client_ip
})
```

Pass `forwarded_for`. Without it Auth0's brute-force protection sees only your server's address, so every
failed login in your tenant looks like it came from one place.

To revoke a refresh token:

```elixir
Token.revoke(client_id, refresh_token)
#=> :ok
```

### Authentication API

These call the tenant root rather than `/api/v2`, and send no management token.

```elixir
Auth0Ex.Authentication.signup(
  client_id,
  "someone@example.com",
  "a-strong-password",
  "Username-Password-Authentication"
)

Auth0Ex.Authentication.change_password(client_id, "someone@example.com", "Username-Password-Authentication")

# Sends the token as an Authorization: Bearer header
Auth0Ex.Authentication.userinfo(access_token)
#=> {:ok, %{"sub" => "auth0|abc123", "email" => "someone@example.com"}}

# Machine-to-machine, no user involved
Auth0Ex.Authentication.Token.client_credentials(client_id, client_secret, "https://your-api/")
```

Request bodies follow each endpoint's own documentation: the `/oauth/*` token endpoints are
form-encoded, as OAuth 2.0 and Auth0 specify, and `/dbconnections/*` is JSON.

## Error handling

Every API function returns one of:

```elixir
{:ok, body}                  # a 2xx with a body, decoded from JSON
:ok                          # a 2xx with no body
{:error, %Auth0Ex.Error{}}   # everything else
```

Auth0 fails in three unrelated ways — it answers with an error status, the request never reaches it, or no
management token can be obtained — and all three arrive as one struct, so you need one clause rather than
three:

```elixir
case Auth0Ex.Management.User.get(user_id) do
  {:ok, user} -> user
  {:error, %Auth0Ex.Error{reason: :not_found}} -> nil
  {:error, %Auth0Ex.Error{} = error} -> raise error
end
```

`Auth0Ex.Error` carries:

| Field | |
|---|---|
| `reason` | An atom, always present. `:bad_request`, `:unauthorized`, `:forbidden`, `:not_found`, `:conflict`, `:rate_limited`, `:server_error`, `:http_error`; a transport reason such as `:timeout`; or a token failure — `:token_fetch_failed`, `:missing_access_token`, `:malformed_token` |
| `status` | The HTTP status, or `nil` if the request never got one |
| `body` | The decoded response body |
| `headers` | The response headers |

It is an exception, so `raise error` works when you would rather not handle the failure.

Because headers are kept, you can honour Auth0's rate limiting rather than guessing:

```elixir
{:error, %Auth0Ex.Error{reason: :rate_limited} = error} ->
  Process.sleep((Auth0Ex.Error.retry_after(error) || 1) * 1000)
```

A Management call needs a token before it can be made. When one cannot be obtained, the call returns an
error and never reaches the endpoint you asked for.

## API coverage

This library covers a subset of the Auth0 API. It does not support endpoints Auth0 has deprecated or
retired, so there is currently no login, password-grant, MFA, or RBAC-write path. See
[ROADMAP.md](ROADMAP.md) for what is implemented, what is missing, and what is planned.

`Auth0Ex.Management.User.all/1` defaults to `search_engine=v3`, the only engine Auth0 still supports. Pass
an explicit `search_engine` to override it.

## Authors

- [Tristan Peralta](https://github.com/tristanperalta) — maintainer of this fork
- [techgaun](https://github.com/techgaun) — original author of [auth0_ex](https://github.com/techgaun/auth0_ex)
