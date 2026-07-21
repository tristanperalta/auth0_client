defmodule Auth0Ex.Authentication.Token do
  @moduledoc """
  Exchanges credentials for tokens at Auth0's OAuth 2.0 endpoints.

  Bodies here are `application/x-www-form-urlencoded`, which is what RFC 6749 and
  Auth0's own docs specify for the token endpoint. The rest of the Authentication
  API takes JSON.

  https://auth0.com/docs/api/authentication
  """

  use Auth0Ex.Api
  @path "oauth/token"
  @revoke_path "oauth/revoke"

  @doc """
  This is the OAuth 2.0 grant that regular web apps utilize in order to
  access an API. Use this endpoint to exchange an Authorization Code for a Token.

      iex> Auth0Ex.Authentication.Token.auth_code("client_id", "client_secret", "code")
      iex> Auth0Ex.Authentication.Token.auth_code("client_id", "client_secret", "code", "redirect_uri_here")
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

      iex> Auth0Ex.Authentication.Token.auth_code_pkce("client_id", "code", "code_verifier")
      iex> Auth0Ex.Authentication.Token.auth_code_pkce("client_id", "code", "code_verifier", %{redirect_uri: "redirect_uri_here"})
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
  This is the OAuth 2.0 grant that server processes utilize in order to access an API.
  Use this endpoint to directly request an access_token by using the Client Credentials
  (a Client Id and a Client Secret).

      iex> Auth0Ex.Authentication.Token.client_credentials("client_id", "client_secret", "API_IDENTIFIER_aud")
  """
  def client_credentials(client_id, client_secret, audience) do
    %{
      client_id: client_id,
      client_secret: client_secret,
      audience: audience,
      grant_type: "client_credentials"
    }
    |> post_token()
  end

  @doc """
  Exchanges a refresh token for a fresh access token.

  `opts` may carry `:client_secret` (for a confidential client) and `:scope`.

  https://auth0.com/docs/api/authentication/refresh-token/refresh-token

      iex> Auth0Ex.Authentication.Token.refresh("client_id", "a_refresh_token")
      iex> Auth0Ex.Authentication.Token.refresh("client_id", "a_refresh_token", %{client_secret: "secret"})
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

      iex> Auth0Ex.Authentication.Token.password("client_id", "user@example.com", "pwd")
      iex> Auth0Ex.Authentication.Token.password("client_id", "user@example.com", "pwd", %{realm: "Username-Password-Authentication", forwarded_for: "198.51.100.7"})
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

      iex> Auth0Ex.Authentication.Token.revoke("client_id", "a_refresh_token")
  """
  def revoke(client_id, token, opts \\ %{}) when is_map(opts) do
    payload = %{
      client_id: client_id,
      token: token,
      client_secret: Map.get(opts, :client_secret)
    }

    post_form(@revoke_path, payload, [])
  end

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
