# Logging users in

How to authenticate an end user — the redirect flow, the direct grants, and the calls around them. If your
tenant requires a second factor, finish with the [MFA guide](mfa.md).

Assumes you have an Auth0 application with its client ID, and that `domain` is configured. See
[Configuration](configuration.md).

## The authorization code flow

`/authorize` and the logout endpoints are browser redirects, not API calls, so `Auth0Ex.Authentication.Url`
builds URLs for you to redirect to rather than requesting them itself.

```elixir
alias Auth0Ex.Authentication.{Token, Url}

# 1. send the browser to Auth0
Url.authorize(client_id, %{
  redirect_uri: "https://app.example.com/callback",
  scope: "openid profile email",
  state: state
})
#=> "https://your-tenant.auth0.com/authorize?client_id=…&response_type=code&…"

# 2. Auth0 redirects back with ?code=… — exchange it
Token.auth_code(client_id, client_secret, code, "https://app.example.com/callback")
#=> {:ok, %{"access_token" => …, "refresh_token" => …, "id_token" => …}}

# 3. later, swap the refresh token for a fresh access token
Token.refresh(client_id, refresh_token, %{client_secret: client_secret})

# 4. log out — again a redirect
Url.logout(%{returnTo: "https://app.example.com", client_id: client_id})
```

Auth0 reference:
[authorize](https://auth0.com/docs/api/authentication/authorization-code-flow/authorize-application),
[get token](https://auth0.com/docs/api/authentication/authorization-code-flow/get-token),
[refresh](https://auth0.com/docs/api/authentication/refresh-token/refresh-token),
[logout](https://auth0.com/docs/api/authentication/logout/auth-0-logout).

`Url.logout/1` requires `returnTo`, and it must be listed in your tenant's allowed logout URLs.
`Url.oidc_logout/1` is the OIDC-conformant variant, which takes an `id_token_hint` instead.

### Public clients: PKCE

A SPA or mobile app has no client secret. Pass `code_challenge` and `code_challenge_method` to
`Url.authorize/2`, then exchange with no secret:

```elixir
Token.auth_code_pkce(client_id, code, code_verifier)
```

Auth0 reference:
[PKCE](https://auth0.com/docs/api/authentication/authorization-code-flow-with-pkce/get-token-pkce).

## Username and password directly

Possible, though a redirect to `/authorize` is preferred. The grant must be enabled on the application in
the Auth0 dashboard:

```elixir
Token.password(client_id, "user@example.com", password, %{
  realm: "Username-Password-Authentication",
  forwarded_for: client_ip
})
```

Pass `forwarded_for`. Without it Auth0's brute-force protection sees only your server's address, so every
failed login in your tenant looks like it came from one place.

Auth0 reference:
[resource owner password](https://auth0.com/docs/api/authentication/resource-owner-password-flow/get-token).

If the tenant requires MFA this call returns a 403 rather than tokens — see [MFA](mfa.md).

## Passwordless

```elixir
Auth0Ex.Authentication.passwordless_start(%{
  client_id: client_id,
  connection: "email",
  email: "user@example.com",
  send: "code"
})

Token.passwordless(client_id, "user@example.com", "123456", "email")
```

Send `send: "link"` instead and the user follows the link; there is no second call. For SMS, use
`connection: "sms"` with a `phone_number`, and pass the phone number as the username when exchanging.

Auth0 reference:
[start](https://auth0.com/docs/api/authentication/passwordless/get-code-or-link),
[authenticate](https://auth0.com/docs/api/authentication/passwordless/authenticate-user).

## Signing users up and resetting passwords

These call the tenant root rather than `/api/v2`, and send no management token.

```elixir
Auth0Ex.Authentication.signup(
  client_id,
  "a-strong-password",
  "Username-Password-Authentication",
  %{email: "someone@example.com"}
)

Auth0Ex.Authentication.change_password(client_id, "someone@example.com", "Username-Password-Authentication")
```

Auth0 requires only `password` and `connection`, so everything else goes in the trailing map. A
phone-based connection sends `phone_number` instead of `email`, and needs no dummy address:

```elixir
Auth0Ex.Authentication.signup(client_id, password, "sms-connection", %{phone_number: "+15551234567"})
```

`change_password/4` sends the user an email; it does not change the password directly. To set one as an
administrator, use `Auth0Ex.Management.User.update/2`, or issue a ticket with
`Auth0Ex.Management.Ticket.password_change/1`. Pass `%{organization: org_id}` to brand the email for one
organization.

Auth0 reference:
[signup](https://auth0.com/docs/api/authentication/signup/create-a-new-user),
[change password](https://auth0.com/docs/api/authentication/change-password/change-password).

## Reading a user's profile

```elixir
Auth0Ex.Authentication.userinfo(access_token)
#=> {:ok, %{"sub" => "auth0|abc123", "email" => "someone@example.com"}}
```

The token goes in an `Authorization: Bearer` header, which is the only form Auth0 documents — and keeps it
out of access logs.

Auth0 reference: [userinfo](https://auth0.com/docs/api/authentication/user-profile/get-user-info).

## Machine-to-machine

No user involved; the application authenticates as itself:

```elixir
Token.client_credentials(client_id, client_secret, "https://your-api/")

# scoped to one organization
Token.client_credentials(client_id, client_secret, "https://your-api/", %{organization: "org_abc123"})
```

To authenticate with Private Key JWT instead of a shared secret, pass `nil` for the secret and supply a
signed assertion. Registering the key is covered in [Applications](applications.md):

```elixir
Token.client_credentials(client_id, nil, "https://your-api/", %{
  client_assertion: signed_jwt,
  client_assertion_type: "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
})
```

Auth0 reference:
[client credentials](https://auth0.com/docs/api/authentication/client-credential-flow/get-token).

## Revoking a refresh token

```elixir
Token.revoke(client_id, refresh_token)
#=> :ok
```

Auth0 reference:
[revoke](https://auth0.com/docs/api/authentication/revoke-refresh-token/revoke-refresh-token).

## Verifying tokens yourself

```elixir
Auth0Ex.Authentication.jwks()
Auth0Ex.Authentication.openid_configuration()
```

Both are unauthenticated and effectively static. Cache them — this library does not, so calling them per
request costs a round trip per request.
