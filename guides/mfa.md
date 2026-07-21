# Multi-factor authentication

MFA spans three modules, and you will usually need all three:

| | |
|---|---|
| `Auth0Ex.Management.Guardian` | tenant-wide configuration — which factors exist, how they are delivered |
| `Auth0Ex.Authentication.Mfa` | the end user's own authenticators, and challenging them at login |
| `Auth0Ex.Authentication.Token` | exchanging a verified challenge for tokens |

Assumes you already have a working login — see [Logging users in](login.md).

Auth0 reference: [Guardian](https://auth0.com/docs/api/management/v2/guardian),
[MFA endpoints](https://auth0.com/docs/api/authentication/multi-factor-authentication).

## Configuring the tenant

```elixir
alias Auth0Ex.Management.Guardian

Guardian.factors()
#=> {:ok, [%{"name" => "otp", "enabled" => false}, ...]}

Guardian.update_factor("otp", %{enabled: true})
Guardian.update_policies(["all-applications"])   # a bare list, not a map
```

`update_factor/2` and `update_policies/1` take effect immediately for every user in the tenant.

For providers offering both verbs, `update_*` merges (`PATCH`) and `replace_*` overwrites the whole
configuration (`PUT`):

```elixir
Guardian.update_apns(%{sandbox: true})                        # merge
Guardian.replace_apns(%{bundle_id: "com.example.app", ...})   # overwrite
```

Auth0 exposes no way to read the FCM configuration back — `update_fcm/1` and `replace_fcm/1` exist, but
there is no `fcm/0`. That asymmetry with APNs and SNS is Auth0's, not an omission here.

## Enrolling a user

Out of band, as an administrator — hand the user the `ticket_url`, or let Auth0 email it:

```elixir
{:ok, %{"ticket_url" => url}} =
  Guardian.create_enrollment_ticket(%{user_id: "auth0|abc123", send_mail: false})
```

Or from the user's own session, with `Auth0Ex.Authentication.Mfa`:

```elixir
alias Auth0Ex.Authentication.Mfa

Mfa.associate(access_token, %{authenticator_types: ["otp"]})
Mfa.authenticators(access_token)
Mfa.delete_authenticator(access_token, "totp|dev_abc123")
```

`associate/2` normally needs an access token with the `enroll` scope and audience
`https://{your_domain}/mfa/`. **A user with no factors yet cannot obtain one**, so Auth0 lets you pass the
`mfa_token` from an `mfa_required` error instead — which is what makes first-time enrolment possible.

The response carries recovery codes **once**, on the first authenticator only. Show them to the user then;
they cannot be retrieved again.

To inspect or reset enrolment as an administrator:

```elixir
Auth0Ex.Management.User.enrollments("auth0|abc123")
Auth0Ex.Management.User.delete_authenticators("auth0|abc123")
```

`enrollments/1` returns the first confirmed enrolment, not every one the user has.

## Completing an MFA login

When the tenant requires MFA, the password grant does not fail — it returns a **403 carrying an
`mfa_token`**, which you exchange after challenging the user. A caller matching only on `{:ok, _}` never
sees it, so the flow starts from the error:

```elixir
alias Auth0Ex.Authentication.{Mfa, Token}

{:error, %Auth0Ex.Error{body: %{"error" => "mfa_required", "mfa_token" => mfa_token}}} =
  Token.password(client_id, "user@example.com", password)

# Challenge the user; for an authenticator app this needs no delivery step
{:ok, _} = Mfa.challenge(%{mfa_token: mfa_token, client_id: client_id})

# Exchange the code they read off their app
{:ok, tokens} = Token.verify_otp(client_id, mfa_token, "123456")
```

### Out-of-band factors

Push, SMS and voice return an `oob_code` from the challenge instead:

```elixir
{:ok, %{"oob_code" => oob_code, "binding_method" => binding}} =
  Mfa.challenge(%{mfa_token: mfa_token, client_id: client_id, challenge_type: "oob"})

# binding_method "prompt" means the user must also type a short code
Token.verify_oob(client_id, mfa_token, oob_code, %{binding_code: "1234"})
```

### Recovery codes

A user who has lost their device uses a recovery code.

```elixir
{:ok, %{"recovery_code" => new_code}} =
  Token.verify_recovery_code(client_id, mfa_token, old_code)
```

> #### The response carries a replacement {: .warning}
>
> The recovery code just used is spent. Show `new_code` to the user and have them store it — dropping it
> silently leaves them with no way back in.
