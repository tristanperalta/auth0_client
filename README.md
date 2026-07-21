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

Alternatively, supply a pre-created Management API token. It is used for every request as-is, and is never
refreshed:

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
`Log`, `ResourceServer`, `Ticket`, `User`, `UserBlock`.

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

Auth0Ex.Authentication.Token.client_credentials(client_id, client_secret, "https://your-api/")

Auth0Ex.Authentication.Token.auth_code(client_id, client_secret, code, redirect_uri)

# PKCE, for public clients that have no secret
Auth0Ex.Authentication.Token.auth_code_pkce(client_id, code, code_verifier)
```

## Error handling

Every API function returns one of:

```elixir
{:ok, body}                      # 200/201, body decoded from JSON
:ok                              # 204 No Content
{:error, body, status_code}      # any other status, body decoded
{:error, %{reason: reason}}      # transport failure, or no management token
```

A Management call needs a token before it can be made. When one cannot be obtained — bad credentials, a
rate-limited tenant, an unreachable network — the call returns `{:error, %{reason: reason}}` and never
reaches the endpoint you asked for. `reason` is one of `:token_fetch_failed` (carrying `:status` and
`:body`), `:missing_access_token`, `:malformed_token`, or the underlying transport reason.

## API coverage

This library covers a subset of the Auth0 API. It does not support endpoints Auth0 has deprecated or
retired, so there is currently no login, password-grant, MFA, or RBAC-write path. See
[ROADMAP.md](ROADMAP.md) for what is implemented, what is missing, and what is planned.

`Auth0Ex.Management.User.all/1` defaults to `search_engine=v3`, the only engine Auth0 still supports. Pass
an explicit `search_engine` to override it.

## Authors

- [Tristan Peralta](https://github.com/tristanperalta) — maintainer of this fork
- [techgaun](https://github.com/techgaun) — original author of [auth0_ex](https://github.com/techgaun/auth0_ex)
