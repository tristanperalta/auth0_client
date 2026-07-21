# Roadmap

Where this library stands against the Auth0 API, and what to build next.

Endpoint counts come from Auth0's [OpenAPI 3.1 document](https://auth0.com/docs/api/management/openapi.json)
for the Management API, enumerated programmatically, and from the
[Authentication API reference](https://auth0.com/docs/api/authentication) page by page. Audited 2026-07-21.

A doc URL returning HTTP 200 does not prove an endpoint exists — retired resources still render the generic
Management API index. Absence from the OpenAPI document and from the resource nav is the reliable signal.

## Coverage at a glance

| API | Implemented | Total | |
|---|---|---|---|
| Management v2 | 55 | 451 | ~12% |
| Authentication | 3 | ~30 | one of the three is implemented incorrectly |

Management resource groups: 7 fully covered, 5 partial, 37 with no coverage at all.

- **Full:** `device-credentials`, `emails`, `logs`, `resource-servers`, `rules`, `tickets`, `user-blocks`
- **Partial:** `users` 13/39, `clients` 6/14, `connections` 6/28, `client-grants` 4/6, `jobs` 1/5

No implemented endpoint has a wrong path or HTTP method. The gaps are omission, not corruption.

---

## 1. Foundation

`Auth0Ex.Api.do_request/4` in `lib/auth0_ex/api.ex` builds headers solely from `Utils.req_header/1`, so no
call site can set a per-request header. That single limitation blocks the `userinfo` fix, every `/mfa/*`
endpoint, and `auth0-forwarded-for`. Do this before adding endpoints that need it.

- [ ] Per-request headers — thread an extra-headers argument through `do_request`, merging case-insensitively
      so a per-call `Authorization` replaces the default rather than being sent alongside it
- [ ] Prune nil-valued keys before `Jason.encode!` so optional params can genuinely be omitted, rather than
      being sent as explicit JSON `null`
- [ ] Optional form-encoded bodies for `/oauth/token`. Auth0's samples use
      `application/x-www-form-urlencoded`; the library always sends JSON. Auth0 appears to accept JSON, so
      this is a risk to close, not a known break
- [ ] URL-only builders for endpoints that are browser redirects rather than calls the library should make
      (`/authorize`, logout)

## 2. Known-broken

- [ ] **`Authentication.userinfo/1` sends the token in the query string.** Auth0 documents only the
      `Authorization: Bearer` header form; no `access_token` query parameter appears in the current
      reference. Also leaks the token into access logs. Blocked on per-request headers.
      [Docs](https://auth0.com/docs/api/authentication/user-profile/get-user-info)
- [ ] **`Token.auth_code_pkce/5` requires `client_secret`.** PKCE exists for public clients, which have no
      secret, and the parameter is not documented for that exchange. The current signature makes it a
      required positional argument with no way to omit it.
      [Docs](https://auth0.com/docs/api/authentication/authorization-code-flow-with-pkce/get-token-pkce)
- [ ] **`User.default_params/0` appends `search_engine=v3` to every call**, including POST, PATCH and DELETE,
      where it is undocumented. It should apply to searches only (the `:v2_search` flag it branches on is
      itself slated for removal — see §3)
- [ ] **`Utils.fetch_mgmt_token/0` raises on any non-success response.** It strict-matches
      `{:ok, %{"access_token" => token}}`, so a 429, a 401 or a timeout on `/oauth/token` raises
      `MatchError` rather than returning an error tuple. The token cache bounds the blast radius to cold
      start and post-expiry, which is exactly when a tenant is most likely to be rate-limiting

## 3. Removals

This library does not support endpoints Auth0 has deprecated or retired. The surface below is dead code on
modern tenants and is to be removed, not maintained.

- [ ] **`Auth0Ex.Management.Rule`** — deprecated 2023-05-16, read-only since 2024-11-18, **end-of-life
      2026-11-18**. `Rule.create/1` and `Rule.update/2` already fail on live tenants. `Action` is the
      replacement (§5)
      [Lifecycle](https://auth0.com/docs/troubleshoot/product-lifecycle/deprecations-and-migrations)
- [ ] **`Login.database/6`** (`POST /oauth/ro`, deprecated 2017-07-08) — superseded by the Resource Owner
      Password grant (§4)
- [ ] **`Login.social/4`** (`POST /oauth/access_token`) — superseded by `GET /authorize`, or native social
      token exchange for mobile
- [ ] **`Authentication.tokeninfo/1`** (`POST /tokeninfo`) — superseded by `GET /userinfo`
- [ ] **`Auth0Ex.Management.Blacklist`** — `/blacklists/tokens` has no entry in the OpenAPI document and no
      page in the docs nav. Whether it still functions is unverified
- [ ] **The `:v2_search` config flag** — search v2 was retired 2019-06-30, so the flag selects an engine that
      no longer exists (see §2)

Removing `Rule` and `Blacklist` drops two of the seven "fully covered" resource groups, which lowers the
headline coverage number while making the library more correct.

## 4. Authentication API

The library implements 3 of ~11 `/oauth/token` grants and 3 of ~30 documented operations.

**P0**

- [ ] `refresh_token` grant — [docs](https://auth0.com/docs/api/authentication/refresh-token/refresh-token)
- [ ] Resource Owner Password grant (`password` / `password-realm`) — the actual replacement for
      `Login.database/6` — [docs](https://auth0.com/docs/api/authentication/resource-owner-password-flow/get-token)
- [ ] `POST /oauth/revoke` — [docs](https://auth0.com/docs/api/authentication/revoke-refresh-token/revoke-refresh-token)
- [ ] `GET /authorize` URL builder — [docs](https://auth0.com/docs/api/authentication/authorization-code-flow/authorize-application)
- [ ] Logout URL builders: `GET /v2/logout`, `GET|POST /oidc/logout`

**P1**

- [ ] Passwordless: `POST /passwordless/start`, plus the `passwordless/otp` grant
- [ ] MFA: `POST /mfa/challenge`, `POST /mfa/associate`, `GET /mfa/authenticators`,
      `DELETE /mfa/authenticators/{id}`, and the `mfa-otp` / `mfa-oob` / `mfa-recovery-code` grants
- [ ] JWKS and OIDC discovery: `GET /.well-known/jwks.json`, `GET /.well-known/openid-configuration`

**P2 and below**

- [ ] Device Authorization Flow (`POST /oauth/device/code` + `device_code` grant)
- [ ] Pushed Authorization Requests (`POST /oauth/par`)
- [ ] Native social token exchange
- [ ] Global token revocation
- [ ] Back-channel login (CIBA), passkeys, dynamic client registration, SAML/WS-Fed

**Smaller drift, same area**

- [ ] `change_password/3` forces `client_id` (now optional) and cannot pass `organization`
- [ ] `signup/5` forces `client_id` and `email` positionally, though only `password` and `connection` are
      required — username- and phone-based connections have to pass a dummy email
- [ ] `client_credentials/3` cannot pass `organization` or use Private Key JWT (`client_assertion`)
- [ ] No `auth0-forwarded-for` support (needs per-request headers)

## 5. Management API

Ordered by value. Counts are endpoints in each group.

- [ ] **`Role` (13)** — the single biggest hole. Nothing in the library can create a role or attach a
      permission
- [ ] **Complete `User` (26 missing)** — `POST`/`DELETE /users/{id}/roles`, the permissions endpoints,
      authentication methods, sessions and refresh-token revocation. RBAC is currently readable but not
      writable
- [ ] **Complete `Job` (4 missing)** — `users-imports`, `users-exports`, `GET /jobs/{id}`, `/jobs/{id}/errors`.
      The module sends verification emails and nothing else, so bulk migration is impossible
- [ ] **`Organization` (42)** — the largest group in the API and the backbone of B2B deployments
- [ ] **`Guardian` (36)** — MFA factor configuration. `User.enrollments/1` currently dangles with no way to
      configure the factors it reports
- [ ] **`Grant` (3) + `UsersByEmail` (1) + `Tenant` (2)** — six endpoints total, all common lookups. Best
      effort-to-value ratio available
- [ ] **`Action` (24)** — successor to Rules. Worth pulling forward given the `Rule` EOL date in §3
- [ ] **`CustomDomain` (9) + `Key` (14)** — production hardening and key rotation

**Next tier:** `EmailTemplate` (4), `LogStream` (5), `AttackProtection` (12), client credentials on `Client`
(5), `Session` (4), `RefreshToken` (5), `Prompt`, `Branding` (23), `NetworkAcl`, `Flow`, `Form`.

**Will not support:** `hooks` (9) and `rules-configs` (3) — both legacy, superseded by Actions.

**Deprioritized as niche:** `experimentation` (23), `verifiable-credentials`, `supplemental-signals`,
`rate-limit-policies`, `risk-assessments`.

`GET /events` is Server-Sent Events and likely needs transport work in `lib/auth0_ex/api.ex` rather than just
a new module.

## 6. Caveats in endpoints that already work

These are correct but incomplete — worth folding into whichever module you touch next.

- [ ] `ResourceServer.all/0` takes no arguments, so pagination and the `identifiers` filter are unreachable.
      It is the only list function in the library without params
- [ ] `Log.search/1` ignores the documented 100-record-per-request cap and the 1,000-result pagination
      ceiling; `include_totals` is deprecated on `/logs`
- [ ] `User.all/1` ignores the 1,000-record cap and v3 search semantics (`.raw` removed,
      `connection` → `identities.connection`, case sensitivity)
- [ ] `Client.all/1` — `q` now requires checkpoint pagination (`from`/`take`) and carries reduced rate limits
- [ ] `Connection.all/1` — more than 1,000 connections requires checkpoint pagination
- [ ] `Connection.update/2` — `name` and `strategy` are immutable, so the module's own doc example is
      invalid; `enabled_clients` is deprecated in favour of `PATCH /connections/{id}/clients`
- [ ] `UserBlock.get/1` and `get_user_block/1` cannot pass `consider_brute_force_enablement`
- [ ] `EmailProvider.configure/1` — the doc example omits the now-required `credentials`
- [ ] `User.enrollments/1` returns the first confirmed MFA enrollment, not all of them as its `@doc` claims
- [ ] `Job.send_verification_email/1` defaults to an empty body, but Auth0 requires `user_id`
- [ ] `Ticket.email_verification/2` silently overrides any `user_id` in the body
- [ ] `build_url/2` always appends `?` even with no params

## 7. Reliability and token handling

Raised by a downstream dependency audit of this library (2026-07-21) and still open. None are API-parity
issues; they are the things that bite under load or partial failure.

- [ ] **`Parser` discards response headers**, so `Retry-After` is unreachable to callers even though Req now
      retries transient failures by default. Rate-limit handling above the library is impossible without it
- [ ] **Token expiry has no skew margin, no single-flight, and no invalidation on 401.** `Utils.expired?/1`
      compares against `DateTime.utc_now()` exactly, so a token expiring mid-flight is used anyway; N
      concurrent callers on a cold cache all fetch their own token; and a token rejected as expired by Auth0
      is never evicted
- [ ] **`TokenState` is a plain named Agent with a public `get_all/0`** holding the management JWT. Any
      process can read it, and it will appear in a crash dump or an `inspect` of process state. Consider
      narrowing the API or scrubbing it from error reports
- [ ] **`http_opts` is an unvalidated pass-through** to `Req.request/1`. A caller can disable certificate
      verification through it — `connect_options: [transport_opts: [verify: :verify_none]]` — with nothing in
      the library flagging it. Worth documenting loudly, and possibly rejecting outright

### Settled, recorded so it is not re-litigated

- **TLS verification is enforced.** Re-verified on the Req/Finch path after the migration: expired,
  hostname-mismatch and self-signed certificates are all rejected, a valid host succeeds. Trust now comes
  from OTP's system CA store via Mint rather than `certifi` via hackney, so the pre-migration evidence chain
  no longer applies — this is the current one
- **The `httpoison ~> 2.2` resolver constraint is gone.** It previously blocked consumers from moving to
  httpoison 3.0 / hackney 4.0. Dropping HTTPoison removes hackney from this library's dependency tree
  entirely, along with the EOL 1.x advisories it carried
- **Error bodies are now decoded maps** rather than raw JSON strings. Consumers that called `Jason.decode!/1`
  on `{:error, body, status}` themselves must drop that call — it will raise on an already-decoded map
