# Auth0Ex

![Build Status](https://github.com/tristanperalta/auth0_client/actions/workflows/main.yml/badge.svg)

> An elixir client library for Auth0

This is a fork of [techgaun/auth0_ex](https://github.com/techgaun/auth0_ex). The repository is named
`auth0_client`, but the OTP application, module namespace and config key remain `:auth0_ex` /
`Auth0Ex` so the library stays drop-in compatible with the original.

## Installation

You can install the stable version from hex:

```elixir
def deps do
[{:auth0_ex, "~> 0.9"}]
end
```

You can use github repo as your package source to use the latest source code but beware it might have breaking and unstable code:

```elixir
def deps do
  [{:auth0_ex, github: "tristanperalta/auth0_client"}]
end
```
## Configuration

Add a configuration block like below:

- First option is to use management api client.

You can create non-interactive client for management api as described [HERE](https://auth0.com/docs/api/management/v2/tokens).
Once you do that, you should be able to grab client ID and client secret from the setting page for use with Auth0Ex.
This is a recommended setup as Auth0Ex can recreate new `access_token` when the current one expires.

```elixir
config :auth0_ex,
  domain: System.get_env("AUTH0_DOMAIN"),
  mgmt_client_id: System.get_env("AUTH0_MGMT_CLIENT_ID"),
  mgmt_client_secret: System.get_env("AUTH0_MGMT_CLIENT_SECRET"),
  http_opts: []
```

- Second option is to use pre-created token with access to management API.

```elixir
config :auth0_ex,
  domain: System.get_env("AUTH0_DOMAIN"),
  mgmt_token: System.get_env("AUTH0_MGMT_TOKEN"),
  http_opts: []
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

### Notes

- The v2 `search_engine` API is being deprecated by Auth0. User queries now specify `search_engine=v3` by default. If for some reason you need the `v2` engine you can set `v2_search: true` in your config block.
- if you use pre-created management token, it will always be used for your requests.
- `AUTH0_DOMAIN` should be entire tenant domain Auth0 provides. We fall back to adding `auth0.com` right now but that will be removed in future version. This allows us to use `Auth0Ex` in all tenant regions unlike the previous versions.
- If you don't want `auth0.com` to be added, you can set `config :auth0_ex, custom_domain: true`

Export appropriate environment variable and you should be all set.

Please refer to the [documentation](https://hexdocs.pm/auth0_ex/) for more details.

### API coverage

This library covers a subset of the Auth0 API, and does not support endpoints Auth0 has deprecated or
retired. See [ROADMAP.md](ROADMAP.md) for what is implemented, what is missing, and what is being removed.

### Authentication API

In addition to the management API resources, there is also a support for most used authentication APIs.
Authentication API will use the same `domain` config you specify in the config above. If you wish to use `Auth0Ex`
for authentication APIs only, all you need to specify is `domain` in config.

## Authors

- [Tristan Peralta](https://github.com/tristanperalta) — maintainer of this fork
- [techgaun](https://github.com/techgaun) — original author of [auth0_ex](https://github.com/techgaun/auth0_ex)
