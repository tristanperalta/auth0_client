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
| Management v2 | 50 | 451 | ~11% |
| Authentication | 3 | ~30 | plus 3 of ~11 `/oauth/token` grants |

Management resource groups: 6 fully covered, 5 partial, 38 with no coverage at all.

- **Full:** `device-credentials`, `emails`, `logs`, `resource-servers`, `tickets`, `user-blocks`
- **Partial:** `users` 13/39, `clients` 6/14, `connections` 6/28, `client-grants` 4/6, `jobs` 1/5

The count dropped from 55 because the `rules` group (5 operations) was removed rather than fixed — see §3.
`blacklists` was never in the OpenAPI document, so removing it changes no count.

No implemented endpoint has a wrong path or HTTP method, and as of the correctness pass none has a wrong
parameter shape either.

---

## 1. Foundation

- [x] Per-request headers — `Utils.request_headers/2` merges caller-supplied headers over the defaults,
      case-insensitively, so a per-call `Authorization` replaces the default rather than being sent
      alongside it. `do_get/3` and `do_post/3` expose it
- [x] Omit nil-valued optional parameters instead of sending explicit JSON `null`. **Scoped deliberately**
      to payloads this library constructs with optional defaults (`Token.auth_code/4`,
      `auth_code_pkce/4`). A blanket transform in `do_post`/`do_patch` would break Management PATCH calls,
      where an explicit `null` is how you *clear* a field
- [ ] Optional form-encoded bodies for `/oauth/token`. Auth0's samples use
      `application/x-www-form-urlencoded`; the library always sends JSON. Auth0 appears to accept JSON, so
      this is a risk to close, not a known break
- [ ] URL-only builders for endpoints that are browser redirects rather than calls the library should make
      (`/authorize`, logout) — belongs with the P0 work in §4

## 2. Known-broken

- [x] **`Authentication.userinfo/1` sent the token in the query string.** Now sent as
      `Authorization: Bearer`, the only form Auth0 documents, which also keeps it out of access logs.
      [Docs](https://auth0.com/docs/api/authentication/user-profile/get-user-info)
- [x] **`Token.auth_code_pkce/5` required `client_secret`.** Now `auth_code_pkce/4`:
      `(client_id, code, code_verifier, opts)`, where `opts` may carry `:redirect_uri` and, for a
      confidential client, `:client_secret`.
      [Docs](https://auth0.com/docs/api/authentication/authorization-code-flow-with-pkce/get-token-pkce)
- [x] **`search_engine=v3` leaked onto every User call.** Now applied in `User.all/1` only, via
      `Map.put_new/3`, so an explicit `search_engine` still wins
- [x] **`Utils.fetch_mgmt_token/0` raised on any non-success response.** `mgmt_token/0` now returns
      `{:ok, token} | {:error, reason}`, header construction is fallible, and `do_request` short-circuits.
      A management call against a rate-limited tenant returns `{:error, %{reason: :token_fetch_failed,
      status: 429, body: _}}` and never reaches the endpoint

## 3. Removals

This library does not support endpoints Auth0 has deprecated or retired.

- [x] **`Auth0Ex.Management.Rule`** — deprecated 2023-05-16, read-only since 2024-11-18, end-of-life
      2026-11-18. `Action` is the replacement (§5)
      [Lifecycle](https://auth0.com/docs/troubleshoot/product-lifecycle/deprecations-and-migrations)
- [x] **The whole `Auth0Ex.Authentication.Login` module** — `database/6` (`POST /oauth/ro`, deprecated
      2017-07-08) and `social/4` (`POST /oauth/access_token`) were its only two functions. Replacements are
      the Resource Owner Password grant and `GET /authorize` respectively, both in §4
- [x] **`Authentication.tokeninfo/1`** (`POST /tokeninfo`) — superseded by `GET /userinfo`
- [x] **`Auth0Ex.Management.Blacklist`** — `/blacklists/tokens` has no entry in the OpenAPI document and no
      page in the docs nav
- [x] **The `:v2_search` config flag** — search v2 was retired 2019-06-30, so the flag selected an engine
      that no longer exists

## 4. Authentication API

The library implements 3 of ~11 `/oauth/token` grants and 3 of ~30 documented operations.

**P0**

- [ ] `refresh_token` grant — [docs](https://auth0.com/docs/api/authentication/refresh-token/refresh-token)
- [ ] Resource Owner Password grant (`password` / `password-realm`) — the replacement for the removed
      `Login.database/6`, so there is currently no password-grant path at all
      — [docs](https://auth0.com/docs/api/authentication/resource-owner-password-flow/get-token)
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
