# Roadmap

Where this library stands against the Auth0 API, and what to build next.

Endpoint counts come from Auth0's [OpenAPI 3.1 document](https://auth0.com/docs/api/management/openapi.json)
for the Management API, enumerated programmatically, and from the
[Authentication API reference](https://auth0.com/docs/api/authentication) page by page. Audited 2026-07-21.

Two things that look like evidence and are not:

- **A doc URL returning HTTP 200 does not prove an endpoint exists.** Retired resources still render the
  generic Management API index. Absence from the OpenAPI document and from the resource nav is the reliable
  signal.
- **The OpenAPI `deprecated` flag is unreliable.** Every `guardian` endpoint reads `deprecated: false`,
  including five whose own description begins "This endpoint has been deprecated." Read the description
  text, and check the
  [product lifecycle page](https://auth0.com/docs/troubleshoot/product-lifecycle/deprecations-and-migrations);
  the flag is at best a weak positive signal.

## Coverage at a glance

| API | Implemented | Total | |
|---|---|---|---|
| Management v2 | 174 | 451 | ~39% |
| Authentication | 17 | ~30 | plus 9 of ~11 `/oauth/token` grants |

Management resource groups: 9 fully covered, 6 partial, 34 with no coverage at all.

- **Full:** `device-credentials`, `emails`, `jobs`, `logs`, `resource-servers`, `roles`, `tickets`,
  `user-blocks`, `users`
- **Partial:** `organizations` 37/42, `guardian` 30/36, `actions` 14/24, `clients` 6/14,
  `connections` 6/28, `client-grants` 4/6

The `rules` group (5 operations) was removed rather than fixed — see §3 — so the count went 55 → 50 before
RBAC took it to 73. `blacklists` was never in the OpenAPI document, so removing it changed no count.

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
- [x] Form-encoded bodies where Auth0 documents them. `do_post_form/3` sends `/oauth/token` and
      `/oauth/revoke` as `application/x-www-form-urlencoded`, per RFC 6749 and Auth0's docs.
      `/dbconnections/*` stays JSON — see the encoding rule in §7
- [x] URL-only builders for endpoints that are browser redirects rather than calls the library should
      make — `Auth0Ex.Authentication.Url`
- [x] Multipart uploads — `do_post_multipart/2`, for `POST /jobs/users-imports`, which Auth0 accepts in no
      other encoding. Needs `Utils.drop_header/2` rather than `merge_headers/2`: Req sets the multipart
      content-type with `put_new_header`, so the default `application/json` would win and the boundary
      would never be sent
- [x] `do_delete/3` with per-request headers, for `DELETE /mfa/authenticators/{id}`
- [ ] **The macro's verbs are unevenly featured.** Each capability has been added to one verb at a time as
      an endpoint demanded it: `do_get`/`do_post` took extra headers first, `do_delete` only later; keyword
      params were added to `do_get` before `do_delete`. Nothing is broken, but the next verb-shaped gap will
      surface the same way. Worth one pass to make headers and keyword params uniform across all of them

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

Implemented: `/dbconnections/signup`, `/dbconnections/change_password`, `/userinfo`, `/authorize`,
`/v2/logout`, `/oidc/logout`, `/oauth/revoke`, `/passwordless/start`, the four `/mfa/*` endpoints,
`/.well-known/jwks.json`, `/.well-known/openid-configuration`, and `/oauth/token` with the
`authorization_code`, PKCE, `client_credentials`, `refresh_token`, `password` / `password-realm`,
`mfa-otp`, `mfa-oob`, `mfa-recovery-code` and `passwordless/otp` grants.

**P0 — done. The authorization-code flow is complete end to end.**

- [x] `refresh_token` grant — `Token.refresh/3`
      — [docs](https://auth0.com/docs/api/authentication/refresh-token/refresh-token)
- [x] Resource Owner Password grant — `Token.password/4`, switching to `password-realm` when given a
      `:realm`. Replaces the removed `Login.database/6`
      — [docs](https://auth0.com/docs/api/authentication/resource-owner-password-flow/get-token)
- [x] `POST /oauth/revoke` — `Token.revoke/3`, normalising Auth0's empty 200 body to `:ok`
      — [docs](https://auth0.com/docs/api/authentication/revoke-refresh-token/revoke-refresh-token)
- [x] `GET /authorize` URL builder — `Url.authorize/2`
      — [docs](https://auth0.com/docs/api/authentication/authorization-code-flow/authorize-application)
- [x] Logout URL builders — `Url.logout/1` (`/v2/logout`) and `Url.oidc_logout/1` (`/oidc/logout`)

**P1 — done. An MFA login can now be completed end to end.**

- [x] Passwordless — `Authentication.passwordless_start/1` and `Token.passwordless/5`
- [x] MFA — `Auth0Ex.Authentication.Mfa` (`challenge/1`, `associate/2`, `authenticators/1`,
      `delete_authenticator/2`) plus `Token.verify_otp/4`, `verify_oob/4` and `verify_recovery_code/4`.
      Closes the gap where `Token.password/4` reported `mfa_required` and nothing could act on it
- [x] JWKS and OIDC discovery — `Authentication.jwks/0` and `openid_configuration/0`

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
- [x] `auth0-forwarded-for` — supported on `Token.password/4` via `:forwarded_for`, so brute-force
      protection sees the end user's address rather than the server's

## 5. Management API

Ordered by value. Counts are endpoints in each group.

- [x] **`Role` (13 of 13)** — `Auth0Ex.Management.Role`. CRUD, permissions, users and groups. The group is
      fully covered
- [x] **`User` RBAC** — `assign_roles/2`, `remove_roles/2`, the permissions endpoints, `organizations/2`,
      and the `effective-*` lookups that resolve access inherited through groups
- [x] **Complete `User` (39 of 39)** — authentication methods, sessions and refresh-token revocation,
      `revoke_access/2`, groups, connected accounts and risk-assessment clearing. The group is fully covered
- [x] **Complete `Job` (5 of 5)** — `users_imports/3`, `users_exports/1`, `get/1` and `errors/1`. Bulk
      migration works in both directions; import required multipart support, added in §1
- [x] **`Organization` (37 of 42)** — `Auth0Ex.Management.Organization`. CRUD, members, member roles,
      invitations, connections, client grants, discovery domains and groups. The five `/enabled_connections`
      endpoints are deliberately not wrapped — see §7
- [x] **`Guardian` (30 of 36)** — `Auth0Ex.Management.Guardian`. Factors, policies, enrollment tickets, and
      phone, push and Duo provider configuration. Pairs with `User.enrollments/1` and
      `User.delete_authenticators/1`, which previously had no configuration side. The six
      `/guardian/factors/sms/*` endpoints are deprecated and not wrapped — see §7
- [ ] **`Grant` (3) + `UsersByEmail` (1) + `Tenant` (2)** — six endpoints total, all common lookups. Best
      effort-to-value ratio available
- [x] **`Action` (14 of 24)** — `Auth0Ex.Management.Action`. Actions CRUD, deploy, test, versions and
      rollback, executions, triggers and bindings. Closes the gap left by removing `Rule` in §3, ahead of
      that end-of-life date. Actions themselves are current and actively developed — none of their
      endpoints is deprecated. The 10 `/actions/modules` endpoints are deferred — see §7
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
- [x] `User.all/1` — v3 search semantics and the 1,000-record cap are now documented on the function, with
      a pointer to `Job.users_exports/1` for anything larger. `get/2` also accepts a keyword list now,
      matching `all/1`
- [ ] `Client.all/1` — `q` now requires checkpoint pagination (`from`/`take`) and carries reduced rate limits
- [ ] `Connection.all/1` — more than 1,000 connections requires checkpoint pagination
- [ ] `Connection.update/2` — `name` and `strategy` are immutable, so the module's own doc example is
      invalid; `enabled_clients` is deprecated in favour of `PATCH /connections/{id}/clients`
- [ ] `UserBlock.get/1` and `get_user_block/1` cannot pass `consider_brute_force_enablement`
- [ ] `EmailProvider.configure/1` — the doc example omits the now-required `credentials`
- [x] `User.enrollments/1` — the `@doc` claimed "all Guardain enrollments"; corrected to say Auth0 returns
      only the first confirmed enrollment
- [x] `Job.send_verification_email/1` — the empty-body default is gone, so a call without `user_id` fails
      to compile rather than at runtime
- [ ] `Ticket.email_verification/2` silently overrides any `user_id` in the body
- [ ] `build_url/2` always appends `?` even with no params

## 7. Reliability and token handling

Raised by a downstream dependency audit of this library (2026-07-21) and still open. None are API-parity
issues; they are the things that bite under load or partial failure.

- [x] **`Parser` discarded response headers**, making `Retry-After` unreachable. Failures are now a single
      `Auth0Ex.Error` struct carrying `reason`, `status`, `body` and `headers`, with
      `Auth0Ex.Error.retry_after/1` to read the backoff. This also collapsed the two error shapes into one,
      which was itself a source of `FunctionClauseError` in a consuming app
- [x] **Token expiry had no skew margin, no single-flight, and no invalidation on 401.** `TokenState` is now
      a GenServer that owns the token: one fetch in flight at a time with all callers waiting on it,
      renewal `Config.token_refresh_skew/0` seconds before expiry (60 by default), and a 401 on a
      Management call evicts the token and replays the request once
- [x] **`TokenState` exposed the management JWT** through a public `get_all/0`. The key-value API is gone —
      only `fetch/0` and `invalidate/0` remain — and an `Inspect` implementation redacts the token so it
      cannot reach a crash dump or a stray `inspect`
- [ ] **`http_opts` is an unvalidated pass-through** to `Req.request/1`. A caller can disable certificate
      verification through it — `connect_options: [transport_opts: [verify: :verify_none]]` — with nothing in
      the library flagging it. The README now says so; rejecting it outright is the part still open

### Settled, recorded so it is not re-litigated

- **Every 2xx is a success, and a 2xx with an empty body means `:ok`.** Auth0 answers equivalent mutations
  with 200, 201 or 204 depending on the endpoint, and accepted-but-asynchronous ones — deploying an action
  — with 202. `Parser` treats the whole 200..299 range as success and collapses the empty-bodied ones to
  `:ok`, so callers never get a meaningless `{:ok, ""}` and no endpoint needs its own special case.
- **`/actions/modules` is deferred, not rejected.** The 10 endpoints share reusable code between actions,
  which is orthogonal to replacing a Rule. This is why `actions` reads 14/24.
- **`/guardian/factors/sms/*` is not wrapped.** Five of the six say "This endpoint has been deprecated" in
  their own description and name a `/guardian/factors/phone/*` replacement taking the same payload; the
  sixth says a new phone endpoint with the same payload exists. Applying §3's rule, they are excluded —
  which is why `guardian` reads 30/36. Note they all read `deprecated: false` in the OpenAPI document,
  which is what prompted the methodology correction at the top of this file.
- **`/organizations/{id}/enabled_connections` is deliberately not wrapped.** Auth0 ships it alongside
  `/organizations/{id}/connections` with the same semantics; neither is formally deprecated, but
  `/connections` takes a superset of the body (`organization_connection_name`, `organization_access_level`,
  `is_enabled`). Wrapping both would ship two near-identical function families and make callers guess.
  This is why `organizations` reads 37/42 rather than fully covered — it is a choice, not a gap.
- **Some endpoints take a request body on `DELETE`.** Unusual, but documented — the RBAC remove operations
  work this way. `do_delete_body/2` exists for exactly those; `do_delete/2` still means query params.
- **Request encoding is decided per endpoint, from that endpoint's own docs — not by a house convention.**
  `/oauth/token` and `/oauth/revoke` are form-encoded, as RFC 6749 and Auth0 both specify.
  `/dbconnections/*` is JSON: it carries `user_metadata`, typed `object` in the docs, and form encoding
  has no representation for a nested object — `URI.encode_query/1` raises on one. `/jobs/users-imports` is
  `multipart/form-data`, which Auth0 accepts in no other encoding. Three encodings, each chosen per
  endpoint. Do not "unify" these.
- **TLS verification is enforced.** Re-verified on the Req/Finch path after the migration: expired,
  hostname-mismatch and self-signed certificates are all rejected, a valid host succeeds. Trust now comes
  from OTP's system CA store via Mint rather than `certifi` via hackney, so the pre-migration evidence chain
  no longer applies — this is the current one
- **The `httpoison ~> 2.2` resolver constraint is gone.** It previously blocked consumers from moving to
  httpoison 3.0 / hackney 4.0. Dropping HTTPoison removes hackney from this library's dependency tree
  entirely, along with the EOL 1.x advisories it carried
- **Error bodies are now decoded maps** rather than raw JSON strings. Consumers that called `Jason.decode!/1`
  on `{:error, body, status}` themselves must drop that call — it will raise on an already-decoded map
