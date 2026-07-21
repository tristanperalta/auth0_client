defmodule Auth0Ex.Authentication do
  @moduledoc """
  A module with various functions related to authentication api for Auth0.

  Unlike the management API code, most of the authentication code
  sit in this module as it makes sense for management API given the
  resourceful nature of each object but as useful for Authentication APIs.
  """
  use Auth0Ex.Api
  @db_conn_path "dbconnections"

  @doc """
  Creates a user in a database connection.

  Auth0 requires only `password` and `connection`. Everything else — `email`,
  `username`, `phone_number`, `given_name`, `user_metadata` — goes in `opts`, so a
  username- or phone-based connection does not have to invent an email address.

  The default database connection is named `Username-Password-Authentication`; find
  yours under Connections → Database in the dashboard.

  https://auth0.com/docs/api/authentication/signup/create-a-new-user

      iex> Auth0Ex.Authentication.signup(client_id, "password", "Username-Password-Authentication", %{email: "samar@example.com"})
      iex> Auth0Ex.Authentication.signup(client_id, "password", "sms-connection", %{phone_number: "+15551234567"})
      iex> Auth0Ex.Authentication.signup(client_id, "password", connection, %{email: "a@b.com", user_metadata: %{plan: "silver"}})
  """
  def signup(client_id, password, connection, opts \\ %{}) when is_map(opts) do
    %{
      client_id: client_id,
      password: password,
      connection: connection
    }
    |> Map.merge(opts)
    |> then(&do_post("#{@db_conn_path}/signup", &1))
  end

  @doc """
  Sends the user a change-password email.

  This does not change the password — it emails a link. To set one directly as an
  administrator use `Auth0Ex.Management.User.update/2`, or issue a ticket with
  `Auth0Ex.Management.Ticket.password_change/1`.

  `opts` may carry `organization`, to brand the email for one organization.

  https://auth0.com/docs/api/authentication/change-password/change-password

      iex> Auth0Ex.Authentication.change_password(client_id, "samar@example.com", "Username-Password-Authentication")
      iex> Auth0Ex.Authentication.change_password(client_id, "samar@example.com", connection, %{organization: "org_abc123"})
  """
  def change_password(client_id, email, connection, opts \\ %{}) when is_map(opts) do
    payload =
      Map.merge(
        %{client_id: client_id, email: email, connection: connection},
        opts
      )

    do_post("#{@db_conn_path}/change_password", payload)
  end

  @doc """
  Given the Auth0 access token obtained during login, this endpoint returns a user's profile.
  This endpoint will work only if `openid` was granted as a scope for the `access_token`.

  The token is sent as a bearer header. Auth0 documents no query-parameter form, and a
  token in a query string leaks into access logs.

  https://auth0.com/docs/api/authentication/user-profile/get-user-info

      iex> Auth0Ex.Authentication.userinfo("sample.access_token.here")
  """
  def userinfo(access_token) do
    do_get("userinfo", %{}, [{"Authorization", "Bearer #{access_token}"}])
  end

  @doc """
  Starts a passwordless login by sending the user a code or a magic link.

  `client_id` and `connection` are required; `connection` is `"email"` or `"sms"`.
  Supply `email` or `phone_number` to match. `send` chooses `"code"` or `"link"`,
  defaulting to a link. `authParams` carries `scope`, `state` and friends through to
  the eventual authorization.

  For a code, finish with `Auth0Ex.Authentication.Token.passwordless/5`. A link
  needs no second call — the user follows it.

  https://auth0.com/docs/api/authentication/passwordless/get-code-or-link

      iex> Auth0Ex.Authentication.passwordless_start(%{client_id: "a_client_id", connection: "email", email: "user@example.com", send: "code"})
      iex> Auth0Ex.Authentication.passwordless_start(%{client_id: "a_client_id", connection: "sms", phone_number: "+15551234567"})
  """
  def passwordless_start(body) when is_map(body) do
    do_post("passwordless/start", body)
  end

  @doc """
  Fetches the tenant's JSON Web Key Set, for verifying token signatures locally.

  Unauthenticated, and it changes only when keys rotate. Cache it — this library
  does not, so calling it per request means a network round trip per request.

      iex> Auth0Ex.Authentication.jwks()
  """
  def jwks, do: do_get(".well-known/jwks.json", %{})

  @doc """
  Fetches the tenant's OpenID Connect discovery document.

  Unauthenticated, and effectively static. Cache it, as with `jwks/0`.

      iex> Auth0Ex.Authentication.openid_configuration()
  """
  def openid_configuration, do: do_get(".well-known/openid-configuration", %{})

  @doc """
  Starts the Device Authorization Flow, for a device with no browser.

  A CLI, a TV app, a headless installer — anything that cannot host a redirect. Show
  the user the returned `user_code` and `verification_uri` (or send them straight to
  `verification_uri_complete`, which embeds the code), then poll
  `Auth0Ex.Authentication.Token.device/3` until they finish.

  Returns `device_code`, `user_code`, `verification_uri`, `verification_uri_complete`,
  `expires_in` and `interval` — the last being the number of seconds to wait between
  polls.

  `opts` may carry `:scope` and `:audience`. Include `offline_access` in `scope` to
  get a refresh token back from the exchange.

  https://auth0.com/docs/api/authentication/device-authorization-flow/authorize-device

      iex> Auth0Ex.Authentication.device_code("a_client_id")
      iex> Auth0Ex.Authentication.device_code("a_client_id", %{scope: "openid profile offline_access", audience: "https://your-api/"})
  """
  def device_code(client_id, opts \\ %{}) when is_map(opts) do
    %{
      client_id: client_id,
      scope: Map.get(opts, :scope),
      audience: Map.get(opts, :audience)
    }
    |> Map.reject(fn {_key, value} -> is_nil(value) end)
    |> then(&do_post_form("oauth/device/code", &1))
  end

  @doc """
  Pushes authorization parameters to Auth0 and gets back a reference to them.

  Everything you would put in the query string of `/authorize` goes here instead, over
  a back-channel POST, so sensitive values never reach the browser. Auth0 answers with
  a `request_uri`, which you then hand to `Auth0Ex.Authentication.Url.authorize/2`:

      {:ok, %{"request_uri" => request_uri}} =
        Auth0Ex.Authentication.pushed_authorization_request(client_id, %{
          client_secret: client_secret,
          response_type: "code",
          redirect_uri: "https://app.example.com/callback",
          scope: "openid profile",
          state: state
        })

      Auth0Ex.Authentication.Url.authorize(client_id, %{request_uri: request_uri})

  `response_type` and `redirect_uri` are required alongside `client_id`, and the call
  must carry client authentication — `client_secret`, or `client_assertion` with
  `client_assertion_type`. Every parameter must be a string. The response also carries
  `expires_in`, the seconds the `request_uri` stays valid.

  Auth0 answers `201`, not `200`.

  > #### The reference is named `request_uri` {: .info}
  >
  > Auth0's prose for this endpoint says it responds with a `redirect_uri`. The
  > response schema on the same page says `request_uri`, which is also what RFC 9126
  > specifies and what the API actually returns.

  Requires an Enterprise plan with the Highly Regulated Identity add-on; without it
  the call is rejected rather than merely unused.

  https://auth0.com/docs/api/authentication/authorization-code-flow-with-enhanced-privacy-protection/push-authorization-requests

      iex> Auth0Ex.Authentication.pushed_authorization_request("a_client_id", %{client_secret: "a_secret", response_type: "code", redirect_uri: "https://app.example.com/callback"})
  """
  def pushed_authorization_request(client_id, opts \\ %{}) when is_map(opts) do
    opts
    |> Map.put(:client_id, client_id)
    |> Map.reject(fn {_key, value} -> is_nil(value) end)
    |> then(&do_post_form("oauth/par", &1))
  end

  @doc """
  Revokes a user's sessions and refresh tokens across every application.

  Auth0's implementation of Okta's Universal Logout. Where
  `Auth0Ex.Management.User.revoke_access/2` works within your tenant using a
  management token, this is the cross-application, externally-authenticated form.

  **Access tokens are not revoked** — they keep working until they expire. Only session
  cookies and refresh tokens are destroyed, so a short access-token lifetime is what
  bounds the delay.

  `subject` requires all three of `format`, `iss` and `sub`. `access_token` is the
  bearer token the endpoint authenticates with; it is not the management token, and
  this library does not fetch it for you.

  Unlike the other `/oauth/*` endpoints, this one takes a **JSON** body rather than a
  form-encoded one — Auth0 documents the encoding per endpoint, not per prefix.

  https://auth0.com/docs/api/authentication/logout/global-token-revocation

      iex> Auth0Ex.Authentication.global_token_revocation(
      ...>   "Username-Password-Authentication",
      ...>   %{format: "iss_sub", iss: "https://your-tenant.auth0.com/", sub: "auth0|abc123"},
      ...>   "an_access_token"
      ...> )
  """
  def global_token_revocation(connection_name, subject, access_token)
      when is_binary(connection_name) and is_map(subject) do
    do_post(
      "oauth/global-token-revocation/connection/#{connection_name}",
      %{subject: subject},
      [{"Authorization", "Bearer #{access_token}"}]
    )
  end
end
