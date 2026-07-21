defmodule Auth0Ex.Api do
  @moduledoc """
  The main API module supposed to be used by individual authentication and management API modules

  Example Usage would look something like below:

      use Auth0Ex.Api
      use Auth0Ex.Api, for: :mgmt
  """

  alias Auth0Ex.Config
  alias Auth0Ex.Error
  alias Auth0Ex.Parser
  alias Auth0Ex.TokenState
  alias Auth0Ex.Utils

  defmacro __using__(opts) do
    quote location: :keep do
      alias Auth0Ex.Parser
      import Auth0Ex.Utils

      @doc false
      def build_url(path, params) do
        "#{base_url(unquote(opts)[:for])}#{path}?#{query_string(params)}"
      end

      @doc false
      def do_get(path, params) when is_map(params) do
        do_request(:get, path, params, "")
      end

      @doc false
      def do_get(path, params) when is_list(params) do
        do_get(path, Enum.into(params, %{}))
      end

      @doc false
      def do_get(path, params, extra_headers) when is_list(extra_headers) do
        do_request(:get, path, Enum.into(params, %{}), "", extra_headers)
      end

      def do_post(path, body \\ %{})

      @doc false
      def do_post(path, body) when is_list(body) do
        do_post(path, Enum.into(body, %{}))
      end

      @doc false
      def do_post(path, body) do
        do_request(:post, path, %{}, Jason.encode!(body))
      end

      @doc false
      def do_post(path, body, extra_headers) when is_list(extra_headers) do
        do_request(:post, path, %{}, Jason.encode!(body), extra_headers)
      end

      # OAuth 2.0 (RFC 6749) specifies a form-encoded body for the token endpoints,
      # and Auth0 documents the same. Other Auth0 endpoints take JSON — follow each
      # endpoint's own docs rather than picking a house convention.
      @doc false
      def do_post_form(path, body, extra_headers \\ []) do
        do_request(
          :post,
          path,
          %{},
          URI.encode_query(body),
          merge_headers([{"Content-Type", "application/x-www-form-urlencoded"}], extra_headers)
        )
      end

      @doc false
      def do_put(path, body \\ %{}) do
        do_request(:put, path, %{}, Jason.encode!(body))
      end

      def do_patch(path, body \\ %{})

      @doc false
      def do_patch(path, body) when is_list(body) do
        do_patch(path, Enum.into(body, %{}))
      end

      @doc false
      def do_patch(path, body) do
        do_request(:patch, path, %{}, Jason.encode!(body))
      end

      @doc false
      def do_delete(path) do
        do_request(:delete, path)
      end

      @doc false
      def do_delete(path, params) when is_map(params) do
        do_request(:delete, path, params)
      end

      @doc false
      def do_delete(path, params) when is_list(params) do
        do_delete(path, Enum.into(params, %{}))
      end

      # Several RBAC endpoints send their payload in the body of a DELETE. Unusual
      # for HTTP, but it is what Auth0 documents. Named apart from do_delete/2 so
      # the body cannot be mistaken for query params.
      @doc false
      def do_delete_body(path, body) do
        do_request(:delete, path, %{}, Jason.encode!(body))
      end

      defp do_request(method, path, params \\ %{}, req_body \\ "", extra_headers \\ []) do
        Auth0Ex.Api.request(
          unquote(opts[:for]),
          method,
          build_url(path, params),
          req_body,
          extra_headers
        )
      end

      defp query_string(params) do
        default_params()
        |> Map.merge(params)
        |> URI.encode_query()
      end

      defp default_params do
        %{}
      end

      defoverridable default_params: 0
    end
  end

  @doc """
  Performs a request and parses the response.

  Lives here rather than in the macro so there is one copy of it, and one place for
  the 401 retry below, instead of a copy compiled into every API module.
  """
  @spec request(atom, atom, String.t(), iodata, list) :: Parser.response()
  def request(tag, method, url, req_body, extra_headers) do
    do_request(tag, method, url, req_body, extra_headers, retry_on_401?(tag))
  end

  # A management request needs a token before it can build headers, so header
  # construction may fail. `with` passes that error straight through.
  defp do_request(tag, method, url, req_body, extra_headers, retry?) do
    result =
      with {:ok, headers} <- Utils.request_headers(tag, extra_headers) do
        [method: method, url: url, headers: headers, body: req_body]
        |> Keyword.merge(Utils.http_opts())
        |> Req.request()
        |> Parser.parse()
      end

    maybe_retry(result, tag, method, url, req_body, extra_headers, retry?)
  end

  # A 401 on a management call usually means the cached token was rejected — the
  # secret rotated, or the client was revoked. Evict it and replay once. A 401 means
  # the request did not take effect, so replaying is safe even when it is not
  # idempotent. `retry?` is threaded explicitly so this can never loop.
  defp maybe_retry({:error, %Error{status: 401}}, tag, method, url, req_body, extra_headers, true) do
    TokenState.invalidate()

    do_request(tag, method, url, req_body, extra_headers, false)
  end

  defp maybe_retry(result, _tag, _method, _url, _req_body, _extra_headers, _retry?), do: result

  # Only worth retrying a token this library manages. A statically configured one
  # cannot be refreshed, so a 401 on it will keep being a 401.
  defp retry_on_401?(:mgmt), do: not is_binary(Config.mgmt_token())
  defp retry_on_401?(_tag), do: false
end
