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

## Authors

- [Tristan Peralta](https://github.com/tristanperalta) — maintainer of this fork
- [techgaun](https://github.com/techgaun) — original author of [auth0_ex](https://github.com/techgaun/auth0_ex)
