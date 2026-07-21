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

## Comparison with other Auth0 libraries

Compared against every Auth0 package on hex, as of July 2026. `auth0_ex` is the upstream this was forked from.

### Auth0 features

| | **this library** | [auth0_api](https://hex.pm/packages/auth0_api) | [auth0_ex](https://hex.pm/packages/auth0_ex) | [prima_auth0_ex](https://hex.pm/packages/prima_auth0_ex) | [auth0_jwks](https://hex.pm/packages/auth0_jwks) | [auth0_plug](https://hex.pm/packages/auth0_plug) | [ueberauth_auth0](https://hex.pm/packages/ueberauth_auth0) |
|---|---|---|---|---|---|---|---|
| **Users** — CRUD, search, blocks | ✅ | ✅ | ✅ | — | — | — | — |
| **Tickets** — password change, email verification | ✅ | ✅ | ✅ | — | — | — | — |
| **Roles and permissions** (RBAC) | ✅ | ✅ | — | — | — | — | — |
| **Organizations** (B2B) | ✅ | ✅ | — | — | — | — | — |
| **Clients and grants** | ✅ | ✅ | ✅ | — | — | — | — |
| **Connections** | ✅ | ✅ | ✅ | — | — | — | — |
| **Actions** | ✅ | ✅ | — | — | — | — | — |
| **MFA** (Guardian) | ✅ | ✅ | — | — | — | — | — |
| **Custom domains, signing keys** | ✅ | ✅ | — | — | — | — | — |
| **Jobs** — bulk import/export | ✅ | ✅ | ✅ | — | — | — | — |
| **Logs, log streams** | ✅ | ✅ | ✅ | — | — | — | — |
| **Branding, prompts, email templates** | — | ✅ | — | — | — | — | — |
| **Attack protection, anomaly** | — | ✅ | — | — | — | — | — |
| **Sessions, refresh tokens** | — | ✅ | — | — | — | — | — |
| **Login flows** — auth code, PKCE, passwordless | ✅ | — | ✅ | — | — | — | ✅ |
| **Machine-to-machine tokens** | ✅ | ✅ | ✅ | ✅ | — | — | — |
| **Browser login as an Ueberauth strategy** | — | — | — | — | — | — | ✅ |
| **Inbound JWT verification** (RS256 + JWKS) | — | — | — | ✅ | ✅ | — | — |
| **Plug integration** for request auth | — | — | — | ✅ | ✅ | ✅ ¹ | — |
| **Key rotation** handling | — | — | — | ✅ | ✅ | — | — |

¹ `auth0_plug` verifies with a static symmetric secret (HS256) rather than fetching your tenant's JWKS. Auth0 signs with RS256 by default.

### Library qualities

| | **this library** | auth0_api | auth0_ex | prima_auth0_ex | auth0_jwks | auth0_plug | ueberauth_auth0 |
|---|---|---|---|---|---|---|---|
| Management resource groups | 19 | **~44** | 13 ² | 0 | 0 | 0 | 0 |
| HTTP client | **Req** | HTTPoison | HTTPoison | Telepoison | HTTPoison | none | OAuth2 |
| Single error struct | ✅ | — | — | — | — | — | — |
| Response headers preserved | ✅ | — | — | — | — | — | — |
| `Retry-After` on 429 | ✅ | auto-retry ³ | — | — | — | — | — |
| Token cache renews before expiry | ✅ | — ⁴ | — | ✅ | n/a | n/a | n/a |
| Single-flight token fetch | ✅ | — | — | ✅ | n/a | n/a | n/a |
| Cached token redacted from `inspect` | ✅ | — | — | — | n/a | n/a | n/a |
| Published on hex | — ⁵ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Last release | git | 2025-12 | 2024-03 | **2026-06** | 2024-09 | 2024-06 | 2022-10 |

² Includes `rule` and `blacklist`, which Auth0 has deprecated in favour of Actions.
³ Retries internally and sleeps the calling process, rather than handing the delay back to you.
⁴ Treats a token as valid until five seconds *past* its stated expiry.
⁵ Depend on it from git — see [Installation](#installation).

### Which to use

**This library does not verify incoming tokens.** `Auth0Ex.Authentication.jwks/0` fetches your tenant's key set, but performs no signature verification and pulls in no crypto library. Pair it with `auth0_jwks` or `prima_auth0_ex` if you need to authenticate requests. That separation is deliberate — verifying a token on the request path is cryptographic work that belongs in a library built for it, and none of the Management API packages above attempt it.

**If you need Management API breadth, use `auth0_api`.** It covers roughly twice the surface, including branding, attack protection, sessions and several 2025-era additions. This library covers the resources most applications actually reach for, and spends its effort on the transport instead: one error struct that carries the response headers, and a management token cache designed for concurrent callers.

## Authors

- [Tristan Peralta](https://github.com/tristanperalta) — maintainer of this fork
- [techgaun](https://github.com/techgaun) — original author of [auth0_ex](https://github.com/techgaun/auth0_ex)
