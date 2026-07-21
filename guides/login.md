# Logging users in

How to authenticate an end user — the redirect flow, the direct grants, and the calls around them. If your
tenant requires a second factor, finish with the [MFA guide](mfa.md).

Assumes you have an Auth0 application with its client ID, and that `domain` is configured. See
[Configuration](configuration.md).

## The authorization code flow

`/authorize` and the logout endpoints are browser redirects, not API calls, so `Auth0Client.Authentication.Url`
builds URLs for you to redirect to rather than requesting them itself.

```elixir
alias Auth0Client.Authentication.{Token, Url}

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

### Keeping parameters out of the browser: PAR

Pushed Authorization Requests send the `/authorize` parameters over a back-channel POST and get back a
reference to them, so nothing sensitive appears in a URL:

```elixir
{:ok, %{"request_uri" => request_uri}} =
  Auth0Client.Authentication.pushed_authorization_request(client_id, %{
    client_secret: client_secret,
    response_type: "code",
    redirect_uri: "https://app.example.com/callback",
    scope: "openid profile",
    state: state
  })

Url.authorize(client_id, %{request_uri: request_uri})
```

The response also carries `expires_in`, the seconds the reference stays valid. Requires an Enterprise plan
with the Highly Regulated Identity add-on.

Auth0 reference:
[PAR](https://auth0.com/docs/api/authentication/authorization-code-flow-with-enhanced-privacy-protection/push-authorization-requests).

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
Auth0Client.Authentication.passwordless_start(%{
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

## Devices with no browser

A CLI, a TV app, a headless installer — anything that cannot host a redirect. The device shows a code, the
user types it in on their phone, and the device polls until they are done.

```elixir
{:ok, start} = Auth0Client.Authentication.device_code(client_id, %{
  scope: "openid profile offline_access",
  audience: "https://your-api/"
})

IO.puts("Go to #{start["verification_uri"]} and enter #{start["user_code"]}")
```

Then poll. **The errors here are the flow working, not failing** — `authorization_pending` means the user
has not finished yet, and `slow_down` means you are polling faster than `interval`:

```elixir
def poll(client_id, device_code, interval) do
  case Token.device(client_id, device_code) do
    {:ok, tokens} ->
      {:ok, tokens}

    {:error, %Auth0Client.Error{body: %{"error" => "authorization_pending"}}} ->
      Process.sleep(interval * 1000)
      poll(client_id, device_code, interval)

    {:error, %Auth0Client.Error{body: %{"error" => "slow_down"}}} ->
      Process.sleep((interval + 5) * 1000)
      poll(client_id, device_code, interval + 5)

    {:error, error} ->
      {:error, error}
  end
end

poll(client_id, start["device_code"], start["interval"])
```

> #### Bailing on the first error never completes the login {: .warning}
>
> `authorization_pending` arrives as `{:error, %Auth0Client.Error{}}` like anything else, because that is what
> Auth0 returns. Match on the code in `body`, not on the tuple. `expired_token` and `access_denied` are the
> terminal ones — the codes ran out, or the user refused.

`verification_uri_complete` embeds the user code, so a device that can render a QR code can skip the
typing entirely. Include `offline_access` in `scope` to get a refresh token from the exchange.

Auth0 reference:
[device flow](https://auth0.com/docs/api/authentication/device-authorization-flow/authorize-device).

## Native social sign-in

When a mobile SDK has already authenticated the user — Sign In with Apple, say — exchange the artifact it
returns for Auth0 tokens, with no further user interaction:

```elixir
Token.native_social(
  client_id,
  apple_authorization_code,
  "http://auth0.com/oauth/token-type/apple-authz-code",
  %{user_profile: %{name: %{firstName: "John", lastName: "Smith"}}}
)
```

`user_profile` is a nested object in a form-encoded body, which has no representation for one — Auth0 takes
it as JSON in a single field, and this library encodes it for you.

Omit `scope` and you get every scope defined for the audience, because this grant implies trust in the
application. The issued set can differ from the requested one; read `scope` in the response.

Auth0 discourages this flow outside a genuine native social setting.

Auth0 reference:
[native social](https://auth0.com/docs/api/authentication/token-exchange-for-native-social/token-exchange-native-social).

## Signing users up and resetting passwords

These call the tenant root rather than `/api/v2`, and send no management token.

```elixir
Auth0Client.Authentication.signup(
  client_id,
  "a-strong-password",
  "Username-Password-Authentication",
  %{email: "someone@example.com"}
)

Auth0Client.Authentication.change_password(client_id, "someone@example.com", "Username-Password-Authentication")
```

Auth0 requires only `password` and `connection`, so everything else goes in the trailing map. A
phone-based connection sends `phone_number` instead of `email`, and needs no dummy address:

```elixir
Auth0Client.Authentication.signup(client_id, password, "sms-connection", %{phone_number: "+15551234567"})
```

`change_password/4` sends the user an email; it does not change the password directly. To set one as an
administrator, use `Auth0Client.Management.User.update/2`, or issue a ticket with
`Auth0Client.Management.Ticket.password_change/1`. Pass `%{organization: org_id}` to brand the email for one
organization.

Auth0 reference:
[signup](https://auth0.com/docs/api/authentication/signup/create-a-new-user),
[change password](https://auth0.com/docs/api/authentication/change-password/change-password).

## Reading a user's profile

```elixir
Auth0Client.Authentication.userinfo(access_token)
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
Auth0Client.Authentication.jwks()
Auth0Client.Authentication.openid_configuration()
```

Both are unauthenticated and effectively static. Cache them — this library does not, so calling them per
request costs a round trip per request.
