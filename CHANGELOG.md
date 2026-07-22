# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres
to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] — 2026-07-22

### Fixed

- **`Auth0Client.Config.domain/0` raised the wrong error when `domain` was unset.** It called
  `String.ends_with?/2` on `nil`, so you got a `FunctionClauseError` naming a `String` function instead of
  the `ArgumentError` naming the setting. Since the README and `config/dev.exs` both read the domain from
  `System.get_env("AUTH0_DOMAIN")`, this is what an unset environment variable produced. A non-binary
  `domain` now says so too, and `custom_domain: true` with no domain reports the missing setting rather
  than crashing.
- **`Auth0Client.Authentication.Url.authorize/2` emitted duplicate query parameters** when `client_id` or
  `response_type` was passed as a string key, because it only ever checked for atom keys:

  ```
  authorize("cid", %{"response_type" => "token"})
  #=> ...?client_id=cid&response_type=code&response_type=token   # before
  #=> ...?client_id=cid&response_type=token                      # after
  ```

  Both spellings are now honoured, matching `logout/1`, which already checked both for `returnTo`. The
  positional `client_id` argument wins over a string-keyed one.

### Added

- **`Auth0Client.Utils.bearer/1`**, the `Authorization` header list for a bearer token. Already used
  internally for both the management token and caller-supplied tokens.

## [1.0.0] — 2026-07-22

First release of this fork of [techgaun/auth0_ex](https://github.com/techgaun/auth0_ex), whose last release
was 0.9.0 in March 2024. Everything below is relative to that.

**This release is not drop-in compatible with `auth0_ex`.** See [Migrating](#migrating-from-auth0_ex).

### Changed

- **Renamed throughout.** The OTP application is `:auth0_client`, the module namespace is `Auth0Client`,
  and the config key is `config :auth0_client`. The repository has been `auth0_client` since the fork; the
  code now matches it.
- **Req replaces HTTPoison.** hackney leaves the dependency tree entirely, along with the EOL 1.x
  advisories it carried, and the `httpoison ~> 2.2` constraint that blocked consumers from moving to
  httpoison 3.0. TLS trust now comes from OTP's system CA store via Mint rather than from `certifi`.
- **One failure value.** Every function returns `{:ok, term}`, `:ok`, or `{:error, %Auth0Client.Error{}}`.
  The struct carries `reason`, `status`, `body` and `headers`, and is an exception, so `raise` works. This
  replaces two different error shapes that were themselves a source of `FunctionClauseError` downstream.
- **Error bodies are decoded maps**, not raw JSON strings. Callers that ran `Jason.decode!/1` on the body
  themselves must drop that call.
- **Every 2xx is a success, and a 2xx with an empty body is `:ok`.** Previously only 200 and 201 counted,
  which made `Action.deploy/1` (202) look like a failure.
- **Response headers survive the parse**, so `Auth0Client.Error.retry_after/1` can read the rate-limit
  backoff on a 429.
- **`Auth0Client.Utils.mgmt_token/0` returns `{:ok, token} | {:error, reason}`** rather than raising on any
  non-success response. A management call against a rate-limited tenant now returns an error instead of
  crashing, and never reaches the endpoint.

### Added

Management API coverage went from 55 to 253 of 451 endpoints, with 22 resource groups fully covered.

- **RBAC** — `Role`, and the `effective-*` lookups on `User` that resolve access inherited through groups
- **`Group`**, the other half of that story: group members, and the roles a group grants
- **`Organization`** — members, org-scoped roles, invitations, connections, client grants
- **`Action`**, replacing the deprecated `Rule` ahead of its 2026-11-18 end of life
- **`Connection`** complete, including `Connection.Scim` (inbound provisioning) and
  `Connection.DirectoryProvisioning` (outbound sync)
- **`Client` and `ClientGrant`** complete, including credentials, so Private Key JWT works end to end
- **`Guardian`** — MFA factors, policies, enrollment tickets, and provider configuration
- **`CustomDomain` and `Key`** — domain verification, signing-key rotation, bring-your-own-key
- **`Session` and `RefreshToken`** — inspect and revoke one rather than all of them
- **`Job`** complete — bulk user import and export, import via `multipart/form-data`
- **`Grant`, `Tenant`, `Log`, `EmailProvider`, `Ticket`, `ResourceServer`, `DeviceCredential`, `UserBlock`**

Authentication API coverage went from 3 to 21 endpoints, and all 11 documented `/oauth/token` grants are
now reachable.

- **The authorization code flow, end to end** — `Url.authorize/2`, `Token.auth_code/4`, PKCE, refresh,
  revoke, and both logout URL builders
- **MFA** — `Auth0Client.Authentication.Mfa` plus the `mfa-otp`, `mfa-oob` and `mfa-recovery-code` grants,
  closing the gap where a login could report `mfa_required` and nothing could act on it
- **Passwordless**, **Device Authorization Flow** (for devices with no browser), **Pushed Authorization
  Requests**, **native social token exchange**, and **global token revocation**
- **JWKS and OIDC discovery** — `jwks/0` and `openid_configuration/0`

Other additions:

- **A management token cache built for concurrency.** `Auth0Client.TokenState` renews before expiry rather
  than after, keeps one fetch in flight so a cold cache under load makes one request rather than one per
  caller, evicts a token Auth0 rejects with a 401 and replays the request once, and redacts the cached JWT
  from `inspect/1`.
- **`token_refresh_skew` config**, how many seconds before expiry to renew. Defaults to 60.
- **Per-request headers on every verb.**
- **A documentation set** covering [configuration](guides/configuration.md), [login](guides/login.md),
  [MFA](guides/mfa.md), [users](guides/users.md), [RBAC](guides/rbac.md),
  [organizations](guides/organizations.md), [applications](guides/applications.md),
  [connections](guides/connections.md), [actions](guides/actions.md),
  [domains and keys](guides/domains-and-keys.md) and [error handling](guides/error-handling.md).

### Removed

Endpoints Auth0 has deprecated or retired are not supported.

- **`Auth0Ex.Management.Rule`** — deprecated 2023-05-16, read-only since 2024-11-18, end of life
  2026-11-18. Use `Auth0Client.Management.Action`.
- **`Auth0Ex.Authentication.Login`** — `database/6` (`POST /oauth/ro`, deprecated 2017) and `social/4`
  (`POST /oauth/access_token`). Use the Resource Owner Password grant and `Url.authorize/2`.
- **`Auth0Ex.Authentication.tokeninfo/1`** — superseded by `userinfo/1`.
- **`Auth0Ex.Management.Blacklist`** — `/blacklists/tokens` is in neither the OpenAPI document nor the docs.
- **The `:v2_search` config flag** — user search v2 was retired 2019-06-30.

### Fixed

- **`userinfo/1` sent the access token in the query string**, where it leaked into access logs. It is now
  an `Authorization: Bearer` header, the only form Auth0 documents.
- **`auth_code_pkce/5` required a `client_secret`**, which public clients do not have — the entire reason
  PKCE exists. Now `auth_code_pkce/4`, with the secret optional in `opts`.
- **`search_engine=v3` was sent on every `User` call**, including ones that reject it. It is now applied in
  `User.all/1` only, and an explicit `search_engine` wins.
- **`UserBlock.unblock/1` always raised `BadMapError`.**
- **`build_url/2` appended a trailing `?`** when there was no query string, and raised `BadMapError` on a
  keyword list.
- **`http_opts` could silently disable TLS certificate verification.** `verify: :verify_none` is now
  refused, with `dangerously_disable_tls_verification: true` as an explicit, loudly-named opt-out.

### Migrating from `auth0_ex`

```elixir
# mix.exs
{:auth0_client, "~> 1.0"}
```

```sh
# in your application
sed -i 's/Auth0Ex/Auth0Client/g'      lib/**/*.ex
sed -i 's/:auth0_ex/:auth0_client/g'  config/*.exs
```

Then, in order of how quietly each one fails:

1. **The config key is silent when missed.** `config :auth0_ex` is simply never read, and the first call
   raises about a missing domain rather than about the rename.
2. **Error handling changes shape.** Match on `{:error, %Auth0Client.Error{}}` and drop any
   `Jason.decode!/1` you were applying to the body — it raises on an already-decoded map.
3. **Removed modules** — see above for the replacement of each.
4. **`auth_code_pkce/5` is now `/4`**, and `signup/4` takes `(client_id, password, connection, opts)` with
   `email` in `opts`. Both changed shape rather than name; a guard turns an unmigrated `signup` call into a
   `FunctionClauseError` rather than a wrong request.

[1.1.0]: https://github.com/tristanperalta/auth0_client/releases/tag/v1.1.0
[1.0.0]: https://github.com/tristanperalta/auth0_client/releases/tag/v1.0.0
