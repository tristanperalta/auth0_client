defmodule Auth0Ex.Utils do
  @moduledoc """
  Collection module of various utils needed for Auth0Ex

  Header building is split by whether it can fail. `base_headers/0` is static and
  always succeeds. `request_headers/2` may need a management token, so it returns
  an `:ok`/`:error` tuple — a tenant that rate-limits `/oauth/token` should surface
  as an error tuple from the calling API function, not as a raise.
  """
  alias Auth0Ex.Authentication.Token
  alias Auth0Ex.Config
  alias Auth0Ex.TokenState

  @type reason :: %{
          required(:reason) => atom,
          optional(:status) => integer,
          optional(:body) => term
        }

  def base_url do
    "https://#{Config.domain()}/"
  end

  def base_url(:mgmt), do: "#{base_url()}api/v2/"
  def base_url(_), do: base_url()
  def oauth_url, do: "#{base_url()}oauth/token"

  def http_opts, do: Config.http_opts()
  def ua, do: Config.user_agent()

  @doc """
  The headers sent on every request, regardless of API.
  """
  def base_headers, do: [{"User-Agent", ua()}, {"Content-Type", "application/json"}]

  @doc """
  Builds the headers for a request, merging in any per-request `extra` headers.

  Management requests carry a bearer token, so this returns `{:error, reason}` if
  no token can be obtained.
  """
  @spec request_headers(atom, list) :: {:ok, list} | {:error, reason}
  def request_headers(tag, extra \\ [])

  def request_headers(:mgmt, extra) do
    with {:ok, token} <- mgmt_token() do
      {:ok, merge_headers([{"Authorization", "Bearer #{token}"} | base_headers()], extra)}
    end
  end

  def request_headers(_tag, extra), do: {:ok, merge_headers(base_headers(), extra)}

  @doc """
  Merges `extra` headers into `base`, letting `extra` win on duplicate names.

  Names are compared case-insensitively, so a per-request `Authorization` replaces
  the default one rather than being sent alongside it.
  """
  def merge_headers(base, []), do: base

  def merge_headers(base, extra) do
    replaced = MapSet.new(extra, fn {name, _} -> String.downcase(name) end)

    Enum.reject(base, fn {name, _} -> MapSet.member?(replaced, String.downcase(name)) end) ++
      extra
  end

  @doc """
  Returns the management API token, fetching and caching one if needed.
  """
  @spec mgmt_token() :: {:ok, String.t()} | {:error, reason}
  def mgmt_token do
    case Config.mgmt_token() do
      token when is_binary(token) -> {:ok, token}
      _ -> get_token_from_client()
    end
  end

  defp get_token_from_client do
    case TokenState.get(:mgmt_token) do
      token when is_binary(token) ->
        if expired?(TokenState.get(:exp)) do
          fetch_mgmt_token()
        else
          {:ok, token}
        end

      _ ->
        fetch_mgmt_token()
    end
  end

  defp fetch_mgmt_token do
    client_id = Config.mgmt_client_id()
    client_secret = Config.mgmt_client_secret()

    case Token.client_credentials(client_id, client_secret, base_url(:mgmt)) do
      {:ok, %{"access_token" => token}} ->
        cache_token(token)

      {:ok, body} ->
        {:error, %{reason: :missing_access_token, body: body}}

      {:error, body, status} ->
        {:error, %{reason: :token_fetch_failed, status: status, body: body}}

      {:error, %{reason: _} = reason} ->
        {:error, reason}
    end
  end

  defp cache_token(token) do
    case exp_from_token(token) do
      {:ok, exp} ->
        TokenState.put(:mgmt_token, token)
        TokenState.put(:exp, exp)
        {:ok, token}

      :error ->
        {:error, %{reason: :malformed_token}}
    end
  end

  # A token Auth0 issues is a JWT whose payload carries `exp`. Anything else cannot
  # be cached, since there is no way to know when it stops being valid.
  defp exp_from_token(token) do
    with [_header, payload | _] <- String.split(token, "."),
         {:ok, json} <- Base.url_decode64(payload, padding: false),
         {:ok, %{"exp" => exp}} <- Jason.decode(json) do
      {:ok, exp}
    else
      _ -> :error
    end
  end

  defp expired?(exp) when is_integer(exp), do: exp <= DateTime.to_unix(DateTime.utc_now())
  defp expired?(_), do: true
end
