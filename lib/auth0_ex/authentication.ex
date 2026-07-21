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
  Given a user's credentials, and a connection, this endpoint will create
  a new user using active authentication. This endpoint only works for database connections.

  API Management https://auth0.com/docs/api/authentication#signup

  client_id: is part of your configuration and you should get via `Application.get_env/2`
  connection: is an auth0 concept; They list the following connections `database, social, enterprise, or passwordless connection`.

  A use case should be, we want to use the database connection to create new signup, the value for that connection is in the dashboard inside of `Connections -> Database` or at the URL `https://manage.auth0.com/dashboard/us/<tenant>/connections/database`.

  NOTE: The default name for the database connection is `Username-Password-Authentication`. You can create a new database connection instead.

      iex> client_id = Application.get_env(:auth0_ex, :mgmt_client_id)
      iex> connection = "Username-Password-Authentication"
      iex> Auth0Ex.Authentication.signup(client_id, "samar@example.com", "password", connection, %{user_metadata: %{plan: "silver", team_id: "a111"}})
  """
  def signup(client_id, email, password, connection, extra_params \\ %{}) do
    payload = %{
      client_id: client_id,
      email: email,
      password: password,
      connection: connection
    }

    do_post("#{@db_conn_path}/signup", Map.merge(payload, extra_params))
  end

  @doc """
  Given a user's email address and a connection, Auth0 will send a change password email.
  This endpoint only works for database connections.

  https://auth0.com/docs/api/authentication#change-password

      iex> client_id = Application.get_env(:auth0_ex, :mgmt_client_id)
      iex> connection = "Username-Password-Authentication"
      iex> Auth0Ex.Authentication.change_password(client_id, "samar@example.com", connection)
  """
  def change_password(client_id, email, connection) do
    payload = %{
      client_id: client_id,
      email: email,
      connection: connection
    }

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
end
