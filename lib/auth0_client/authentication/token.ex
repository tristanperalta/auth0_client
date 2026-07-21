defmodule Auth0Client.Authentication.Token do
  @moduledoc """
  Exchanges credentials for tokens at Auth0's OAuth 2.0 endpoints.

  Bodies here are `application/x-www-form-urlencoded`, which is what RFC 6749 and
  Auth0's own docs specify for the token endpoint. The rest of the Authentication
  API takes JSON.

  https://auth0.com/docs/api/authentication
  """

  use Auth0Client.Api
  @path "oauth/token"
  @revoke_path "oauth/revoke"

  @doc """
  This is the OAuth 2.0 grant that regular web apps utilize in order to
  access an API. Use this endpoint to exchange an Authorization Code for a Token.

      iex> Auth0Client.Authentication.Token.auth_code("client_id", "client_secret", "code")
      iex> Auth0Client.Authentication.Token.auth_code("client_id", "client_secret", "code", "redirect_uri_here")
  """
  def auth_code(client_id, client_secret, code, redirect_uri \\ nil) do
    %{
      client_id: client_id,
      client_secret: client_secret,
      code: code,
      redirect_uri: redirect_uri,
      grant_type: "authorization_code"
    }
    |> post_token()
  end

  @doc """
  This is the OAuth 2.0 grant that mobile and single-page apps utilize in order to
  access an API. Use this endpoint to exchange an Authorization Code for a Token.

  PKCE exists for public clients, which have no client secret, so none is sent by
  default. `opts` may carry `:redirect_uri` (required only if it was used in the
  `/authorize` call) and `:client_secret` (for a confidential client that also uses
  PKCE).

  https://auth0.com/docs/api/authentication/authorization-code-flow-with-pkce/get-token-pkce

      iex> Auth0Client.Authentication.Token.auth_code_pkce("client_id", "code", "code_verifier")
      iex> Auth0Client.Authentication.Token.auth_code_pkce("client_id", "code", "code_verifier", %{redirect_uri: "redirect_uri_here"})
  """
  def auth_code_pkce(client_id, code, code_verifier, opts \\ %{}) when is_map(opts) do
    %{
      client_id: client_id,
      code: code,
      code_verifier: code_verifier,
      redirect_uri: Map.get(opts, :redirect_uri),
      client_secret: Map.get(opts, :client_secret),
      grant_type: "authorization_code"
    }
    |> post_token()
  end

  @doc """
  The grant a server process uses to access an API as itself, with no user involved.

  `opts` may carry:

    * `organization` — for a token scoped to one organization
    * `client_assertion` and `client_assertion_type` — to authenticate with Private
      Key JWT rather than a shared secret

  When using Private Key JWT there is no shared secret, so pass `nil` for
  `client_secret`: nil values are pruned from the request, so it is simply omitted.
  Register the key first with `Auth0Client.Management.Client.create_credential/2`, and
  remember to enable it on the application.

  https://auth0.com/docs/api/authentication/client-credential-flow/get-token

      iex> Auth0Client.Authentication.Token.client_credentials("client_id", "client_secret", "API_IDENTIFIER_aud")
      iex> Auth0Client.Authentication.Token.client_credentials("client_id", "client_secret", "aud", %{organization: "org_abc123"})
      iex> Auth0Client.Authentication.Token.client_credentials("client_id", nil, "aud", %{
      ...>   client_assertion: signed_jwt,
      ...>   client_assertion_type: "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
      ...> })
  """
  def client_credentials(client_id, client_secret, audience, opts \\ %{}) when is_map(opts) do
    %{
      client_id: client_id,
      client_secret: client_secret,
      audience: audience,
      organization: Map.get(opts, :organization),
      client_assertion: Map.get(opts, :client_assertion),
      client_assertion_type: Map.get(opts, :client_assertion_type),
      grant_type: "client_credentials"
    }
    |> post_token()
  end

  @doc """
  Exchanges a refresh token for a fresh access token.

  `opts` may carry `:client_secret` (for a confidential client) and `:scope`.

  https://auth0.com/docs/api/authentication/refresh-token/refresh-token

      iex> Auth0Client.Authentication.Token.refresh("client_id", "a_refresh_token")
      iex> Auth0Client.Authentication.Token.refresh("client_id", "a_refresh_token", %{client_secret: "secret"})
  """
  def refresh(client_id, refresh_token, opts \\ %{}) when is_map(opts) do
    %{
      client_id: client_id,
      refresh_token: refresh_token,
      client_secret: Map.get(opts, :client_secret),
      scope: Map.get(opts, :scope),
      grant_type: "refresh_token"
    }
    |> post_token()
  end

  @doc """
  Authenticates a user directly with their username and password.

  Passing a `:realm` in `opts` switches to the password-realm grant, which
  authenticates against one specific connection. `opts` may also carry
  `:audience`, `:scope` and `:client_secret`.

  Set `:forwarded_for` to the end user's IP address. Auth0's brute-force
  protection otherwise sees only your server's address, so every login attempt in
  your tenant looks like it came from one place.

  This grant must be enabled on the application in the Auth0 dashboard.

  https://auth0.com/docs/api/authentication/resource-owner-password-flow/get-token

      iex> Auth0Client.Authentication.Token.password("client_id", "user@example.com", "pwd")
      iex> Auth0Client.Authentication.Token.password("client_id", "user@example.com", "pwd", %{realm: "Username-Password-Authentication", forwarded_for: "198.51.100.7"})
  """
  def password(client_id, username, password, opts \\ %{}) when is_map(opts) do
    realm = Map.get(opts, :realm)

    payload = %{
      client_id: client_id,
      username: username,
      password: password,
      realm: realm,
      audience: Map.get(opts, :audience),
      scope: Map.get(opts, :scope),
      client_secret: Map.get(opts, :client_secret),
      grant_type: grant_type_for_realm(realm)
    }

    post_token(payload, forwarded_for_header(Map.get(opts, :forwarded_for)))
  end

  @doc """
  Revokes a refresh token.

  Auth0 answers a successful revocation with `200` and an empty body, which this
  normalises to a bare `:ok`. `opts` may carry `:client_secret`.

  https://auth0.com/docs/api/authentication/revoke-refresh-token/revoke-refresh-token

      iex> Auth0Client.Authentication.Token.revoke("client_id", "a_refresh_token")
  """
  def revoke(client_id, token, opts \\ %{}) when is_map(opts) do
    payload = %{
      client_id: client_id,
      token: token,
      client_secret: Map.get(opts, :client_secret)
    }

    post_form(@revoke_path, payload, [])
  end

  @doc """
  Completes an MFA login with a one-time code from an authenticator app.

  `mfa_token` comes from the `mfa_required` error the password grant returns;
  `otp` is the code the user reads off their app.

  https://auth0.com/docs/api/authentication/multi-factor-authentication/verify-mfa-with-otp

      iex> Auth0Client.Authentication.Token.verify_otp("client_id", "mfa_tok", "123456")
  """
  def verify_otp(client_id, mfa_token, otp, opts \\ %{}) when is_map(opts) do
    %{
      client_id: client_id,
      mfa_token: mfa_token,
      otp: otp,
      client_secret: Map.get(opts, :client_secret),
      grant_type: "http://auth0.com/oauth/grant-type/mfa-otp"
    }
    |> post_token()
  end

  @doc """
  Completes an MFA login out of band — a push notification, SMS or voice call.

  `oob_code` comes from `Auth0Client.Authentication.Mfa.challenge/1`. Pass
  `binding_code` in `opts` when that challenge answered with
  `binding_method: "prompt"`, which means the user must also type a short code;
  otherwise omit it.

  https://auth0.com/docs/api/authentication/multi-factor-authentication/verify-with-out-of-band

      iex> Auth0Client.Authentication.Token.verify_oob("client_id", "mfa_tok", "oob_code")
      iex> Auth0Client.Authentication.Token.verify_oob("client_id", "mfa_tok", "oob_code", %{binding_code: "1234"})
  """
  def verify_oob(client_id, mfa_token, oob_code, opts \\ %{}) when is_map(opts) do
    %{
      client_id: client_id,
      mfa_token: mfa_token,
      oob_code: oob_code,
      binding_code: Map.get(opts, :binding_code),
      client_secret: Map.get(opts, :client_secret),
      grant_type: "http://auth0.com/oauth/grant-type/mfa-oob"
    }
    |> post_token()
  end

  @doc """
  Completes an MFA login with a recovery code, for a user who has lost their
  authenticator.

  The response may carry a **new** `recovery_code`. The one just used is spent, so
  show the replacement to the user and have them store it — dropping it silently
  leaves them with no way back in.

  https://auth0.com/docs/api/authentication/multi-factor-authentication/verify-with-recovery-code

      iex> Auth0Client.Authentication.Token.verify_recovery_code("client_id", "mfa_tok", "ABCD1234EFGH")
  """
  def verify_recovery_code(client_id, mfa_token, recovery_code, opts \\ %{}) when is_map(opts) do
    %{
      client_id: client_id,
      mfa_token: mfa_token,
      recovery_code: recovery_code,
      client_secret: Map.get(opts, :client_secret),
      grant_type: "http://auth0.com/oauth/grant-type/mfa-recovery-code"
    }
    |> post_token()
  end

  @doc """
  Exchanges a passwordless code for tokens.

  Start the flow with `Auth0Client.Authentication.passwordless_start/1`, then pass the
  code the user received. `realm` must match the connection used there — `"email"`
  or `"sms"` — and `username` is the email address or phone number it was sent to.

  https://auth0.com/docs/api/authentication/passwordless/authenticate-user

      iex> Auth0Client.Authentication.Token.passwordless("client_id", "user@example.com", "123456", "email")
  """
  def passwordless(client_id, username, otp, realm, opts \\ %{}) when is_map(opts) do
    %{
      client_id: client_id,
      username: username,
      otp: otp,
      realm: realm,
      client_secret: Map.get(opts, :client_secret),
      grant_type: "http://auth0.com/oauth/grant-type/passwordless/otp"
    }
    |> post_token()
  end

  @doc """
  Exchanges a device code for tokens, completing the Device Authorization Flow.

  Start the flow with `Auth0Client.Authentication.device_code/2`, show the user its
  `user_code` and `verification_uri`, then call this repeatedly until they finish.

  **The errors here are part of the flow, not failures.** While the user is still
  authorizing, Auth0 answers `authorization_pending`; poll faster than the `interval`
  the start call returned and it answers `slow_down`, meaning lengthen the wait.
  Treating the first `{:error, _}` as fatal means the login never completes:

      def poll(client_id, device_code, interval) do
        case Auth0Client.Authentication.Token.device(client_id, device_code) do
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

  `expired_token` and `access_denied` are the terminal errors — the codes ran out, or
  the user refused.

  `opts` may carry `:client_secret` for a confidential client; a device is normally a
  public client and sends none.

  https://auth0.com/docs/api/authentication/device-authorization-flow/authorize-device

      iex> Auth0Client.Authentication.Token.device("client_id", "a_device_code")
  """
  def device(client_id, device_code, opts \\ %{}) when is_map(opts) do
    %{
      client_id: client_id,
      device_code: device_code,
      client_secret: Map.get(opts, :client_secret),
      grant_type: "urn:ietf:params:oauth:grant-type:device_code"
    }
    |> post_token()
  end

  @doc """
  Exchanges an externally-issued identity artifact for Auth0 tokens.

  For native social sign-in only — a mobile SDK authenticates the user (Sign In with
  Apple, say) and hands your app an artifact, which this turns into Auth0 tokens with
  no further user interaction. Auth0 discourages it outside that setting.

  `subject_token_type` identifies what `subject_token` is; the pair is required.
  `opts` may carry `:audience`, `:scope`, `:forwarded_for` and `:user_profile`.

  `user_profile` is a nested object — `%{name: %{firstName: "John", lastName: "Smith"}}`
  — used for iOS interactions where the profile can be updated. The body here is
  form-encoded, which has no representation for a nested object, so Auth0 takes it as
  JSON inside a single field; this function encodes it for you.

  Because scopes are implied by the trust in this grant, omitting `scope` returns
  every scope defined for the audience, and the issued set may differ from the one
  requested — check the `scope` in the response.

  https://auth0.com/docs/api/authentication/token-exchange-for-native-social/token-exchange-native-social

      iex> Auth0Client.Authentication.Token.native_social("client_id", "apple_id_token", "http://auth0.com/oauth/token-type/apple-authz-code")
  """
  def native_social(client_id, subject_token, subject_token_type, opts \\ %{})
      when is_map(opts) do
    payload = %{
      client_id: client_id,
      subject_token: subject_token,
      subject_token_type: subject_token_type,
      audience: Map.get(opts, :audience),
      scope: Map.get(opts, :scope),
      user_profile: encode_user_profile(Map.get(opts, :user_profile)),
      grant_type: "urn:ietf:params:oauth:grant-type:token-exchange"
    }

    post_token(payload, forwarded_for_header(Map.get(opts, :forwarded_for)))
  end

  # Encoded here rather than in post_form/3: a blanket transform would JSON-encode
  # fields Auth0 expects flat. This is the only nested value any token grant sends.
  defp encode_user_profile(nil), do: nil
  defp encode_user_profile(profile) when is_binary(profile), do: profile
  defp encode_user_profile(profile), do: Jason.encode!(profile)

  defp grant_type_for_realm(nil), do: "password"
  defp grant_type_for_realm(_realm), do: "http://auth0.com/oauth/grant-type/password-realm"

  defp forwarded_for_header(nil), do: []
  defp forwarded_for_header(ip), do: [{"auth0-forwarded-for", ip}]

  defp post_token(payload, extra_headers \\ []), do: post_form(@path, payload, extra_headers)

  # Optional parameters default to nil here rather than being absent, which is an
  # artifact of this module's own signatures. Drop them so the request omits the
  # field entirely, rather than sending it empty — an empty form field is not the
  # same as an absent one.
  defp post_form(path, payload, extra_headers) do
    payload
    |> Map.reject(fn {_key, value} -> is_nil(value) end)
    |> then(&do_post_form(path, &1, extra_headers))
  end
end
