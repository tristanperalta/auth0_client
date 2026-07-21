defmodule Auth0Ex.Authentication.Token do
  @moduledoc """
  A moodule for getting tokens for authentication.
  This is the module that gives you auth codes and client credentials.

  More information at [this page](https://auth0.com/docs/api/authentication?http#get-token)
  """

  use Auth0Ex.Api
  @path "oauth/token"

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

  # Optional parameters default to nil here rather than being absent, which is an
  # artifact of this module's own signatures. Drop them so the request omits the
  # key entirely instead of sending an explicit JSON null.
  defp post_token(payload) do
    payload
    |> Map.reject(fn {_key, value} -> is_nil(value) end)
    |> then(&do_post(@path, &1))
  end
end
