defmodule Auth0Ex.Authentication.Url do
  @moduledoc """
  Builds the Auth0 URLs a browser must be redirected to.

  `/authorize` and the logout endpoints are not API calls — the user's browser has
  to visit them so Auth0 can show a login page and set or clear its session cookie.
  Calling them server-side would defeat the point, so these functions return a URL
  string for you to redirect to:

      conn
      |> Phoenix.Controller.redirect(external: Auth0Ex.Authentication.Url.authorize(client_id))

  Parameters are passed through rather than filtered against an allowlist, so
  anything Auth0 accepts works without waiting on this library.
  """

  import Auth0Ex.Utils, only: [base_url: 0]

  # Flags whose presence alone is the signal. `?federated` and `?federated=true`
  # are not the same thing to Auth0, and URI.encode_query/1 cannot emit a bare key.
  @bare_flags [:federated, "federated"]

  @doc """
  The URL that starts a login.

  `response_type` defaults to `"code"`, for the Authorization Code flow. Only
  `client_id` and `response_type` are required; pass anything else through
  `params` — `redirect_uri`, `scope`, `state`, `audience`, `connection`, `prompt`,
  `organization`, `invitation`, or `code_challenge` and `code_challenge_method`
  for PKCE.

  https://auth0.com/docs/api/authentication/authorization-code-flow/authorize-application

      iex> Auth0Ex.Authentication.Url.authorize("client_id", %{redirect_uri: "https://app.example.com/callback", scope: "openid profile"})
  """
  def authorize(client_id, params \\ %{}) do
    params
    |> Enum.into(%{})
    |> Map.put(:client_id, client_id)
    |> Map.put_new(:response_type, "code")
    |> build("authorize")
  end

  @doc """
  The URL that logs a user out of Auth0.

  `returnTo` is required, and must be listed in your tenant's allowed logout URLs.
  Pass `federated: true` to also log the user out of their upstream identity
  provider.

  https://auth0.com/docs/api/authentication/logout/auth-0-logout

      iex> Auth0Ex.Authentication.Url.logout(%{returnTo: "https://app.example.com", client_id: "client_id"})
  """
  def logout(params \\ %{}) do
    params = Enum.into(params, %{})

    unless Map.has_key?(params, :returnTo) or Map.has_key?(params, "returnTo") do
      raise ArgumentError, "logout/1 requires :returnTo, the URL to send the user back to"
    end

    build(params, "v2/logout")
  end

  @doc """
  The OIDC-conformant logout URL.

  No parameter is strictly required, but without `id_token_hint` — or a
  `logout_hint` matching the user's session — Auth0 asks the user to confirm the
  logout. Pass one of them to log out silently.

  https://auth0.com/docs/api/authentication/logout/oidc-logout

      iex> Auth0Ex.Authentication.Url.oidc_logout(%{id_token_hint: "an_id_token", post_logout_redirect_uri: "https://app.example.com"})
  """
  def oidc_logout(params \\ %{}) do
    params
    |> Enum.into(%{})
    |> build("oidc/logout")
  end

  defp build(params, path) do
    {flags, encodable} = Map.split(params, @bare_flags)

    query =
      [URI.encode_query(encodable) | bare_flags(flags)]
      |> Enum.reject(&(&1 == ""))
      |> Enum.join("&")

    case query do
      "" -> "#{base_url()}#{path}"
      query -> "#{base_url()}#{path}?#{query}"
    end
  end

  defp bare_flags(flags) do
    flags
    |> Enum.reject(fn {_name, value} -> value in [false, nil] end)
    |> Enum.map(fn {name, _value} -> to_string(name) end)
  end
end
