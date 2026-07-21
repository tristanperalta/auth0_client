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

A `domain`, plus credentials for the Management API if you use it:

```elixir
config :auth0_ex,
  domain: System.get_env("AUTH0_DOMAIN"),
  mgmt_client_id: System.get_env("AUTH0_MGMT_CLIENT_ID"),
  mgmt_client_secret: System.get_env("AUTH0_MGMT_CLIENT_SECRET")
```

Tokens are fetched and renewed for you. Using only the Authentication API needs nothing but `domain`.

See [Configuration](guides/configuration.md) for custom domains, pre-created tokens, timeouts and the rest.

## Usage

Each Management resource is a module under `Auth0Ex.Management`:

```elixir
Auth0Ex.Management.User.all(%{q: "email:*@example.com"})
#=> {:ok, [%{"user_id" => "auth0|abc123", ...}]}
```

Available resources: `Action`, `Client`, `ClientGrant`, `Connection`, `CustomDomain`, `DeviceCredential`,
`EmailProvider`, `Grant`, `Guardian`, `Job`, `Key`, `Log`, `Organization`, `ResourceServer`, `Role`,
`Tenant`, `Ticket`, `User`, `UserBlock`.

The Authentication API lives under `Auth0Ex.Authentication`.

## Guides

| | |
|---|---|
| [Configuration](guides/configuration.md) | Every setting, and what it does |
| [Logging users in](guides/login.md) | Authorization code flow, PKCE, passwordless, signup, logout |
| [Multi-factor authentication](guides/mfa.md) | Configuring factors, enrolling users, completing an MFA login |
| [Managing users](guides/users.md) | User CRUD, search, sessions, bulk import and export |
| [Roles and permissions](guides/rbac.md) | RBAC, and tracing where a user's access came from |
| [Organizations](guides/organizations.md) | B2B — members, org-scoped roles, invitations |
| [Applications and credentials](guides/applications.md) | Clients, Private Key JWT, client grants |
| [Connections and provisioning](guides/connections.md) | Identity providers, SCIM, directory sync |
| [Actions](guides/actions.md) | Extending the login flow |
| [Custom domains and keys](guides/domains-and-keys.md) | Branded login domains, signing-key rotation |
| [Error handling](guides/error-handling.md) | Return shapes, `Auth0Ex.Error`, rate limiting |

## API coverage

This library covers a subset of the Auth0 API, and does not wrap endpoints Auth0 has deprecated or
retired. See [ROADMAP.md](ROADMAP.md) for what is implemented, what is missing, and what is deliberately
excluded.

## Choosing between the Auth0 packages

Auth0 work in Elixir splits into three jobs, and no single package does all three. This library does the first one.

| Job | What it means | This library | Alternatives |
|---|---|---|---|
| **Calling Auth0** | Your server calls the Management or Authentication API, authenticated by your client secret | **Yes** | [auth0_api](https://hex.pm/packages/auth0_api), [auth0_ex](https://hex.pm/packages/auth0_ex) |
| **Verifying incoming JWTs** | Checking the signature, `kid` and claims of a token that arrives on a request | **No** | [auth0_jwks](https://hex.pm/packages/auth0_jwks), [prima_auth0_ex](https://hex.pm/packages/prima_auth0_ex), [auth0_plug](https://hex.pm/packages/auth0_plug) |
| **Logging users in via the browser** | Redirecting to Auth0 and handling the callback | **No** | [ueberauth_auth0](https://hex.pm/packages/ueberauth_auth0) |

**This library does not verify incoming tokens.** `Auth0Ex.Authentication.jwks/0` fetches your tenant's key set, but it performs no signature verification and pulls in no crypto library — you will need one of the alternatives above alongside it. That separation is deliberate: verifying a token on the request path is cryptographic work that belongs in a library built for it.

### Against the other Management API packages

- [**auth0_api**](https://hex.pm/packages/auth0_api) covers considerably more of the Auth0 surface than this library does, including recent additions. If you need breadth, look there first.
- [**auth0_ex**](https://hex.pm/packages/auth0_ex) is the upstream this was forked from. It has had no release since March 2024.

What this library offers instead of breadth:

- **Req** for HTTP, so no hackney or httpoison in your dependency tree.
- **One failure value.** Every function returns `{:ok, term}`, `:ok`, or `{:error, %Auth0Ex.Error{}}` — a single struct carrying the reason, status, body and response headers. It is an exception, so `raise` works when you would rather not handle it. See [Error handling](guides/error-handling.md).
- **A management token cache built for concurrency.** Renewal happens before expiry rather than after, only one fetch is ever in flight so a cold cache under load makes one request rather than one per caller, `Auth0Ex.TokenState.invalidate/0` discards a token Auth0 has rejected, and the cached JWT is redacted from `inspect/1` output.
- **`Auth0Ex.Error.retry_after/1`**, because response headers survive the parse — Auth0's Management API is rate limited.

## Authors

- [Tristan Peralta](https://github.com/tristanperalta) — maintainer of this fork
- [techgaun](https://github.com/techgaun) — original author of [auth0_ex](https://github.com/techgaun/auth0_ex)
