# Configuration

Every setting `Auth0Ex` reads, and what it does. For the minimum needed to make a first call, see the
[README](../README.md).

## Domain

`domain` is the whole tenant domain Auth0 gives you, including the region — `your-tenant.us.auth0.com`,
not `your-tenant`. A domain that does not end in `auth0.com` raises `ArgumentError`.

```elixir
config :auth0_ex, domain: System.get_env("AUTH0_DOMAIN")
```

To use a custom domain, set `custom_domain: true` to skip that check:

```elixir
config :auth0_ex,
  domain: "auth.example.com",
  custom_domain: true
```

Using only the Authentication API needs nothing but `domain`.

## Management API credentials

The Management API needs a token. There are two ways to supply one.

### A non-interactive client (recommended)

`Auth0Ex` fetches tokens itself and renews them as they expire. Create a machine-to-machine application as
described in [Auth0's docs](https://auth0.com/docs/api/management/v2/tokens), then take the client ID and
secret from its settings page:

```elixir
config :auth0_ex,
  domain: System.get_env("AUTH0_DOMAIN"),
  mgmt_client_id: System.get_env("AUTH0_MGMT_CLIENT_ID"),
  mgmt_client_secret: System.get_env("AUTH0_MGMT_CLIENT_SECRET")
```

Tokens obtained this way are cached and renewed automatically. Only one fetch is ever in flight, so a cold
cache under load makes one request to Auth0 rather than one per caller.

If Auth0 rejects a cached token with a 401 — a rotated secret, a revoked client — the token is discarded
and the request replayed once with a fresh one, so callers do not need their own retry.

### A pre-created token

A token you supply is used for every request as-is. It is never refreshed, and a 401 is not retried,
because there is nothing to refresh it with:

```elixir
config :auth0_ex,
  domain: System.get_env("AUTH0_DOMAIN"),
  mgmt_token: System.get_env("AUTH0_MGMT_TOKEN")
```

## `token_refresh_skew`

How many seconds before expiry a cached token is renewed. Defaults to 60.

```elixir
config :auth0_ex, token_refresh_skew: 120
```

A token that expires while a request is in flight is rejected, so it is renewed slightly early. Raise this
if your requests are long-running or your clock drifts.

## `http_opts`

Passed straight through to [Req](https://hexdocs.pm/req), which this library uses as its HTTP client. Any
[`Req.request/1` option](https://hexdocs.pm/req/Req.html#request/1) is valid:

```elixir
config :auth0_ex,
  http_opts: [
    receive_timeout: 30_000,
    connect_options: [timeout: 10_000],
    retry: :safe_transient
  ]
```

> #### Options are not validated {: .warning}
>
> Whatever you put here takes effect as written, including options that weaken TLS. Certificate
> verification is on by default; `connect_options: [transport_opts: [verify: :verify_none]]` turns it off,
> and nothing in this library will stop you.

## `user_agent`

The `User-Agent` sent with every request. Defaults to a string identifying this library. Override it if you
want your own application to be identifiable in Auth0's tenant logs:

```elixir
config :auth0_ex, user_agent: "MyApp <https://myapp.example.com>"
```

## Tenant settings

The settings above configure this library. The tenant's own settings — friendly name, default audience and
directory, session lifetimes, hosted pages — live in Auth0 and are read and written through the Management
API:

```elixir
Auth0Ex.Management.Tenant.settings()
Auth0Ex.Management.Tenant.update_settings(%{friendly_name: "Acme"})
```

> #### Tenant settings affect every application {: .warning}
>
> `update_settings/1` takes effect immediately for every login in the tenant. Read `settings/0` first and
> keep the result so a change can be put back.

## Request encoding

You do not configure this, but it is worth knowing that the library does not use one encoding everywhere.
Each endpoint follows its own Auth0 documentation:

| Endpoints | Encoding |
|---|---|
| `/oauth/token`, `/oauth/revoke` | `application/x-www-form-urlencoded`, per [RFC 6749](https://www.rfc-editor.org/rfc/rfc6749#section-4.1.3) |
| `/jobs/users-imports` | `multipart/form-data`, the only encoding Auth0 accepts for it |
| Everything else | `application/json` |
