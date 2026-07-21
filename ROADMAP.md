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
| Management v2 | 253 | 451 | ~56% |
| Authentication | 21 | ~30 | plus 11 of ~11 `/oauth/token` grants |

Management resource groups: 22 fully covered, 3 partial, 24 with no coverage at all.

- **Full:** `client-grants`, `clients`, `connections`, `connections-directory-provisionings`,
  `connections-scim-configurations`, `custom-domains`, `device-credentials`, `emails`, `grants`, `groups`,
  `jobs`, `keys`, `logs`, `refresh-tokens`, `resource-servers`, `roles`, `sessions`, `tenants`, `tickets`,
  `user-blocks`, `users`, `users-by-email`
- **Partial:** `organizations` 37/42, `guardian` 30/36, `actions` 14/24 — all three partial by the
  decisions recorded in §7, not for want of work

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
- [x] **Every verb takes extra headers.** They had been added one verb at a time as endpoints demanded
      them, which is how `do_delete` came to lack them until `/mfa/authenticators` needed one. All eight now
      share the shape `(path, payload_or_params \\ default, extra_headers \\ [])`, and a test asserts each
      one both passes the header through and lets it replace the management token rather than duplicate it.
      Collapsing the `is_map`/`is_list` clause pairs into `Enum.into/2` and one `keyword_to_object/1` helper
      shrank the code generated into all fifteen API modules

      **Not unified: list bodies.** The original note here proposed making keyword-param handling uniform
      too. That would have been wrong. A list body is genuinely ambiguous — a keyword list meant as a JSON
      object, or a real JSON array — and the split is load-bearing, not accidental: `do_post` and
      `do_patch` resolve it as a keyword list, while `do_put` leaves it alone because it is how
      `User.replace_authentication_methods/2` and `Guardian.update_policies/1` send arrays. Unifying them
      raises `ArgumentError` on both. The asymmetry is now named by `keyword_to_object/1`, commented where
      it matters, and pinned by tests

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
`/v2/logout`, `/oidc/logout`, `/oauth/revoke`, `/oauth/par`, `/oauth/device/code`,
`/oauth/global-token-revocation`, `/passwordless/start`, the four `/mfa/*` endpoints,
`/.well-known/jwks.json`, `/.well-known/openid-configuration`, and `/oauth/token` with the
`authorization_code`, PKCE, `client_credentials`, `refresh_token`, `password` / `password-realm`,
`mfa-otp`, `mfa-oob`, `mfa-recovery-code`, `passwordless/otp`, `device_code` and native-social
`token-exchange` grants.

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

**P2 — done. Every documented `/oauth/token` grant is now reachable.**

- [x] Device Authorization Flow — `Authentication.device_code/2` starts it and `Token.device/3` exchanges,
      mirroring the `passwordless_start/1` + `Token.passwordless/5` split. The flow is a polling loop whose
      `authorization_pending` and `slow_down` responses are **errors that mean keep going**, so the `@doc`
      and the guide both show the loop rather than the call
      — [docs](https://auth0.com/docs/api/authentication/device-authorization-flow/authorize-device)
- [x] Pushed Authorization Requests — `Authentication.pushed_authorization_request/2`, answering `201` with
      a `request_uri` that feeds the existing `Url.authorize/2`. Auth0's prose for this endpoint calls the
      field `redirect_uri`; its own response schema and RFC 9126 both say `request_uri`, which is what the
      API returns — recorded so nobody "corrects" it back
- [x] Native social token exchange — `Token.native_social/4`. `user_profile` is a nested object in a
      form-encoded body, which `URI.encode_query/1` cannot represent, so the function JSON-encodes that one
      value. Done in the function rather than in `post_form/3`, where it would silently encode fields Auth0
      expects flat
- [x] Global token revocation — `Authentication.global_token_revocation/3`. Revokes sessions and refresh
      tokens across every application but **not access tokens**, which expire on their own
- [ ] Back-channel login (CIBA), passkeys, dynamic client registration, SAML/WS-Fed

**Smaller drift, same area**

Done. Optional arguments moved into an `opts` map, as decided.

- [x] `change_password/4` takes `opts`, carrying `organization`
- [x] `signup/4` is now `(client_id, password, connection, opts)` with `email` in `opts`, so phone- and
      username-based connections need no dummy address. **The arity did not change**, so an unmigrated
      call would have been silently misread — the `when is_map(opts)` guard turns it into a
      `FunctionClauseError` instead, and a test pins that
- [x] `client_credentials/4` takes `opts`, carrying `organization`, `client_assertion` and
      `client_assertion_type`. Pass `nil` for `client_secret` when using Private Key JWT; nil values are
      pruned, so it is omitted
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
- [x] **`Grant` (3) + `UsersByEmail` (1) + `Tenant` (2)** — `Auth0Ex.Management.Grant` and
      `Auth0Ex.Management.Tenant`. `users-by-email` is `User.by_email/2` rather than a one-function module,
      since that is where a reader looks for it; the group is still fully covered
- [x] **`Action` (14 of 24)** — `Auth0Ex.Management.Action`. Actions CRUD, deploy, test, versions and
      rollback, executions, triggers and bindings. Closes the gap left by removing `Rule` in §3, ahead of
      that end-of-life date. Actions themselves are current and actively developed — none of their
      endpoints is deprecated. The 10 `/actions/modules` endpoints are deferred — see §7
- [x] **`CustomDomain` (9) + `Key` (14)** — `Auth0Ex.Management.CustomDomain` and
      `Auth0Ex.Management.Key`. Domain registration, DNS verification and default promotion; signing-key
      rotation and revocation, encryption keys including bring-your-own-key, and custom signing keys.
      Both groups fully covered
- [x] **Complete `Client` (14) + `ClientGrant` (6)** — credentials, CIMD registration and connections on
      `Client`; `get/1` and `organizations/2` on `ClientGrant`. Pairs with the §4 `client_credentials/4`
      fix so Private Key JWT works end to end rather than half-built. Both groups fully covered
- [x] **Complete `Connection` (28)** — `Auth0Ex.Management.Connection` gains per-client enablement,
      connection keys and the AD/LDAP status check; `Connection.Scim` (9) and
      `Connection.DirectoryProvisioning` (9) cover inbound and outbound provisioning, including the two
      tenant-level listings that sit under their own OpenAPI tags. Three groups fully covered, and the last
      core resource that was partial for want of work
- [x] **`Group` (7) + `Session` (4) + `RefreshToken` (5)** — one theme: make addressable the things `User`
      and `Role` already referenced. `groups` had seven endpoints and no module at all, while
      `User.effective_role_source_groups/2` named groups as the reason a user held a role and nothing could
      open one; `User.sessions/2` and `refresh_tokens/2` listed objects that could only be destroyed all at
      once. Three groups fully covered

**§5's ordered list is complete.** What remains is the next tier below, which has never been ranked
against itself.

**Next tier:** `EmailTemplate` (4), `LogStream` (5), `AttackProtection` (12) + `anomaly` (2), `Prompt` (10),
`Branding` (23), `NetworkAcl` (6), `Flow` (13), `Form` (5), `stats` (2), `self-service-profiles` (9),
`event-streams` (10), `connection-profiles` (7), `user-attribute-profiles` (7),
`token-exchange-profiles` (5).

**Will not support:** `hooks` (9) and `rules-configs` (3) — both legacy, superseded by Actions.

**Deprioritized as niche:** `experimentation` (23), `verifiable-credentials`, `supplemental-signals`,
`rate-limit-policies`, `risk-assessments`.

`GET /events` is Server-Sent Events and likely needs transport work in `lib/auth0_ex/api.ex` rather than just
a new module.

## 6. Caveats in endpoints that already work

These are correct but incomplete — worth folding into whichever module you touch next.

- [x] `ResourceServer.all/1` takes params, so `identifiers` and pagination are reachable
- [x] `Log.search/1` documents the 100-record cap, the 1,000-result ceiling and the deprecated
      `include_totals`
- [x] `User.all/1` — v3 search semantics and the 1,000-record cap are now documented on the function, with
      a pointer to `Job.users_exports/1` for anything larger. `get/2` also accepts a keyword list now,
      matching `all/1`
- [x] `Client.all/1` documents that `q` needs checkpoint pagination and carries reduced rate limits
- [x] `Connection.all/1` documents checkpoint pagination past 1,000 connections
- [x] `Connection.update/2` — the invalid example is replaced, and the immutability of `name` and
      `strategy` documented. The `enabled_clients` replacement it pointed at now exists:
      `Connection.update_clients/2`, which changes one client at a time rather than replacing the list and
      racing anyone else editing the connection
- [x] `UserBlock.get/2` and `get_user_block/2` accept params, so `consider_brute_force_enablement` is
      reachable
- [x] `EmailProvider.configure/1` — the example includes the required `credentials`
- [x] `User.enrollments/1` — the `@doc` claimed "all Guardain enrollments"; corrected to say Auth0 returns
      only the first confirmed enrollment
- [x] `Job.send_verification_email/1` — the empty-body default is gone, so a call without `user_id` fails
      to compile rather than at runtime
- [x] `Ticket.email_verification/2` — the override is documented rather than changed, since callers may
      rely on it
- [x] `build_url/2` appends `?` only when there is a query string. Fixing it surfaced a latent bug:
      `query_string/1` used `Map.merge`, so calling the public `build_url/2` with a keyword list raised
      `BadMapError` — it normalises now

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
  work this way. `do_delete_body/3` exists for exactly those; `do_delete/3` still means query params.
- **`do_put` sends a list as a JSON array; `do_post` and `do_patch` read a *keyword* list as an object.**
  Not an oversight — a list body is ambiguous and each verb resolves it the way its callers need.
  `User.replace_authentication_methods/2` and `Guardian.update_policies/1` depend on the PUT behaviour, and
  converting a list there raises `ArgumentError`. Do not "unify" these either.

  Refined once, when `Connection.update_clients/2` needed to PATCH a JSON array: `keyword_to_object/1`
  now tests `Keyword.keyword?/1` rather than `is_list/1`, so a non-keyword list passes through to POST and
  PATCH as an array instead of raising `ArgumentError` on `Enum.into/2`. That is not the unification this
  note forbids — keyword lists still become objects, `do_put` is untouched, and the old behaviour on a
  non-keyword list was a crash, so nothing could depend on it.
- **Early Access is not a reason to skip an endpoint; deprecated is.** §3's rule is about endpoints Auth0
  is retiring, not ones it is still introducing. `x-release-lifecycle: EA` appears on 37 operations, and
  this library already shipped several before the flag was ever examined — `Organization.connections/2`
  among them — so excluding `GET /refresh-tokens` and `POST /refresh-tokens/revoke` would have invented a
  policy mid-stream and left `refresh-tokens` partial for no stated reason. EA endpoints are wrapped, with
  the lifecycle noted in the `@doc` so a caller can weigh it. The 23 `beta` operations are a separate
  question, and all of them currently fall in groups deprioritized as niche.
- **Request encoding is decided per endpoint, from that endpoint's own docs — not by a house convention.**
  `/oauth/token`, `/oauth/revoke`, `/oauth/par` and `/oauth/device/code` are form-encoded, as RFC 6749 and
  Auth0 both specify. `/dbconnections/*` is JSON: it carries `user_metadata`, typed `object` in the docs,
  and form encoding has no representation for a nested object — `URI.encode_query/1` raises on one.
  `/jobs/users-imports` is `multipart/form-data`, which Auth0 accepts in no other encoding. Three
  encodings, each chosen per endpoint. Do not "unify" these.

  **Not even a shared path prefix is evidence.** `/oauth/global-token-revocation` takes JSON while every
  other `/oauth/*` endpoint here takes a form. And where a form-encoded endpoint genuinely needs a nested
  object — `user_profile` on the native-social grant — Auth0's answer is JSON inside one string field, so
  `Token.native_social/4` encodes that single value itself. That transform belongs in the function, not in
  `post_form/3`, which would encode fields Auth0 expects flat.
- **TLS verification is enforced.** Re-verified on the Req/Finch path after the migration: expired,
  hostname-mismatch and self-signed certificates are all rejected, a valid host succeeds. Trust now comes
  from OTP's system CA store via Mint rather than `certifi` via hackney, so the pre-migration evidence chain
  no longer applies — this is the current one
- **The `httpoison ~> 2.2` resolver constraint is gone.** It previously blocked consumers from moving to
  httpoison 3.0 / hackney 4.0. Dropping HTTPoison removes hackney from this library's dependency tree
  entirely, along with the EOL 1.x advisories it carried
- **Error bodies are now decoded maps** rather than raw JSON strings. Consumers that called `Jason.decode!/1`
  on `{:error, body, status}` themselves must drop that call — it will raise on an already-decoded map
