defmodule Auth0Client.Config do
  @moduledoc """
  All of the configurations pertaining to `Auth0Client`.
  """

  require Logger

  @spec domain() :: String.t()
  def domain do
    auth0_domain = Application.get_env(:auth0_client, :domain)

    cond do
      # Must come first: `or` evaluates left to right, so String.ends_with?/2 would
      # raise on a nil domain before custom_domain?/0 was ever consulted.
      is_nil(auth0_domain) ->
        raise ArgumentError,
              "no :domain is configured. Set it with `config :auth0_client, domain: " <>
                "\"your-tenant.auth0.com\"`, or from the environment if that is where you keep it"

      not is_binary(auth0_domain) ->
        raise ArgumentError, ":domain must be a string, got: #{inspect(auth0_domain)}"

      String.ends_with?(auth0_domain, "auth0.com") or custom_domain?() ->
        auth0_domain

      true ->
        raise ArgumentError,
              "the domain specified must be a fully qualified domain name, it should be : <your_tenant>[.optional_region].auth0.com, not just <your_tenant>"
    end
  end

  @spec mgmt_client_id() :: String.t() | nil
  def mgmt_client_id do
    Application.get_env(:auth0_client, :mgmt_client_id)
  end

  @spec mgmt_client_secret() :: String.t() | nil
  def mgmt_client_secret do
    Application.get_env(:auth0_client, :mgmt_client_secret)
  end

  @spec mgmt_token() :: String.t() | nil
  def mgmt_token do
    Application.get_env(:auth0_client, :mgmt_token)
  end

  @doc """
  Options passed through to `Req.request/1` on every call.

  Refuses to hand back options that disable TLS certificate verification, unless
  `dangerously_disable_tls_verification` is set — see `dangerously_disable_tls_verification?/0`.
  Validated on every read rather than once at boot, so a runtime `Application.put_env/3`
  cannot slip past it.
  """
  @spec http_opts() :: list()
  def http_opts do
    opts = Application.get_env(:auth0_client, :http_opts) || []

    if tls_verification_disabled?(opts) and not dangerously_disable_tls_verification?() do
      raise ArgumentError, tls_verification_message()
    end

    opts
  end

  @doc """
  Whether the caller has explicitly opted out of TLS certificate verification.

  Accepts `"true"` as well as `true`, so an environment variable behaves the same way
  as a literal.
  """
  @spec dangerously_disable_tls_verification?() :: boolean
  def dangerously_disable_tls_verification? do
    Application.get_env(:auth0_client, :dangerously_disable_tls_verification, false) in [
      true,
      "true"
    ]
  end

  @doc """
  Logs a warning when TLS verification has been deliberately disabled.

  Called once when the application starts. `http_opts/0` cannot warn, because it
  runs on every request; and once the opt-in is set, nothing else will ever mention it
  again.
  """
  @spec warn_if_tls_verification_disabled() :: :ok
  def warn_if_tls_verification_disabled do
    opts = Application.get_env(:auth0_client, :http_opts) || []

    if tls_verification_disabled?(opts) and dangerously_disable_tls_verification?() do
      Logger.warning("""
      Auth0Client: TLS certificate verification is DISABLED via \
      dangerously_disable_tls_verification. Auth0 client secrets and management tokens \
      are being sent over connections that are not authenticated.\
      """)
    end

    :ok
  end

  # connect_options -> transport_opts is the only path to TLS settings Req exposes, so
  # there is one spelling to check rather than several. Deliberately narrow: verify_fun
  # can weaken verification but is also how pinning is done, and cacerts/cacertfile are
  # the correct fix for a private CA — rejecting either would push people to verify_none.
  defp tls_verification_disabled?(opts) when is_list(opts) do
    opts
    |> Keyword.get(:connect_options, [])
    |> Keyword.get(:transport_opts, [])
    |> Keyword.get(:verify)
    |> Kernel.==(:verify_none)
  rescue
    # A caller may configure something that is not a keyword list at all. Let Req be the
    # one to complain about the shape; this check only has an opinion about verify_none.
    _ in [ArgumentError, FunctionClauseError] -> false
  end

  defp tls_verification_disabled?(_opts), do: false

  defp tls_verification_message do
    """
    http_opts disables TLS certificate verification \
    (connect_options -> transport_opts -> verify: :verify_none). Auth0 client secrets \
    and management tokens would be sent over connections that are not authenticated.

    To trust a private certificate authority, pass :cacerts or :cacertfile instead:

        config :auth0_client,
          http_opts: [connect_options: [transport_opts: [cacertfile: "/path/to/ca.pem"]]]

    If you genuinely intend to disable verification, say so explicitly:

        config :auth0_client, dangerously_disable_tls_verification: true\
    """
  end

  @doc """
  How many seconds before its expiry a cached management token is refreshed.

  A token that expires while a request is in flight is rejected, so it is renewed
  slightly early. Defaults to 60 seconds.
  """
  @spec token_refresh_skew() :: non_neg_integer
  def token_refresh_skew do
    Application.get_env(:auth0_client, :token_refresh_skew, 60)
  end

  @spec user_agent() :: String.t()
  def user_agent do
    Application.get_env(:auth0_client, :user_agent) ||
      "Auth0Client <https://github.com/tristanperalta/auth0_client>"
  end

  defp custom_domain? do
    Application.get_env(:auth0_client, :custom_domain, false) in [true, "true"]
  end
end
