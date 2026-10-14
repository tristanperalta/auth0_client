defmodule Auth0Client.Api do
  @moduledoc """
  The main API module supposed to be used by individual authentication and management API modules

  Example Usage would look something like below:

      use Auth0Client.Api
      use Auth0Client.Api, for: :mgmt

  Paths are percent-encoded when the URL is built, so callers interpolate raw ids
  (`"users/auth0|abc"`), never pre-encoded ones — `auth0%7Cabc` would be sent as
  `auth0%257Cabc`.
  """

  alias Auth0Client.Config
  alias Auth0Client.Error
  alias Auth0Client.Parser
  alias Auth0Client.TokenState
  alias Auth0Client.Utils

  defmacro __using__(opts) do
    quote location: :keep do
      alias Auth0Client.Parser
      import Auth0Client.Utils

      @doc false
      def build_url(path, params) do
        base = "#{base_url(unquote(opts)[:for])}#{encode_path(path)}"

        case query_string(params) do
          "" -> base
          query -> "#{base}?#{query}"
        end
      end

      @doc false
      def do_get(path, params \\ %{}, extra_headers \\ []) do
        do_request(:get, path, params, "", extra_headers)
      end

      @doc false
      def do_post(path, body \\ %{}, extra_headers \\ []) do
        do_request(:post, path, %{}, Jason.encode!(keyword_to_object(body)), extra_headers)
      end

      # File uploads. Field names must be atoms and values binary, iodata, integer
      # or a File.Stream — Req has no clause for anything else, including booleans.
      @doc false
      def do_post_multipart(path, fields, extra_headers \\ []) do
        do_request(:post, path, %{}, {:form_multipart, fields}, extra_headers)
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

      # Deliberately does NOT convert a list body. PUT is how this library sends a
      # bare JSON array — User.replace_authentication_methods/2 and
      # Guardian.update_policies/1 both need one — so a list here stays a list.
      @doc false
      def do_put(path, body \\ %{}, extra_headers \\ []) do
        do_request(:put, path, %{}, Jason.encode!(body), extra_headers)
      end

      @doc false
      def do_patch(path, body \\ %{}, extra_headers \\ []) do
        do_request(:patch, path, %{}, Jason.encode!(keyword_to_object(body)), extra_headers)
      end

      @doc false
      def do_delete(path, params \\ %{}, extra_headers \\ []) do
        do_request(:delete, path, params, "", extra_headers)
      end

      # Several RBAC endpoints send their payload in the body of a DELETE. Unusual
      # for HTTP, but it is what Auth0 documents. Named apart from do_delete/2 so
      # the body cannot be mistaken for query params.
      @doc false
      def do_delete_body(path, body, extra_headers \\ []) do
        do_request(:delete, path, %{}, Jason.encode!(body), extra_headers)
      end

      # A list body is ambiguous: it may be a keyword list meant as a JSON object,
      # or a genuine JSON array. POST and PATCH resolve a *keyword* list as an object,
      # since that is what most of their callers pass, and leave any other list alone
      # so it is sent as an array — Connection.update_clients/2 needs one. PUT converts
      # nothing at all; it is how this library sends an array from a caller that could
      # just as well have passed a keyword list.
      defp keyword_to_object(body) do
        if Keyword.keyword?(body), do: Map.new(body), else: body
      end

      defp do_request(method, path, params, req_body, extra_headers) do
        Auth0Client.Api.request(
          unquote(opts[:for]),
          method,
          build_url(path, params),
          req_body,
          extra_headers
        )
      end

      # Call sites interpolate ids straight into the path, and Auth0 user ids always
      # carry a `|`, which Mint refuses to send. Escaping everything but unreserved
      # characters and `/` keeps the separators and escapes the ids. An id holding a
      # `/` would be split into segments; no Auth0 id does.
      defp encode_path(path) do
        URI.encode(path, &(URI.char_unreserved?(&1) or &1 == ?/))
      end

      # build_url/2 is public, so params may arrive as a keyword list without having
      # passed through a do_* helper's normalisation.
      defp query_string(params) do
        default_params()
        |> Map.merge(Enum.into(params, %{}))
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
  @spec request(atom, atom, String.t(), iodata | {:form_multipart, list}, list) ::
          Parser.response()
  def request(tag, method, url, req_body, extra_headers) do
    do_request(tag, method, url, req_body, extra_headers, retry_on_401?(tag))
  end

  # A management request needs a token before it can build headers, so header
  # construction may fail. `with` passes that error straight through.
  defp do_request(tag, method, url, req_body, extra_headers, retry?) do
    result =
      with {:ok, headers} <- Utils.request_headers(tag, extra_headers) do
        [method: method, url: url]
        |> Keyword.merge(body_options(req_body, headers))
        |> Keyword.merge(Utils.http_opts())
        |> Req.request()
        |> Parser.parse()
      end

    maybe_retry(result, tag, method, url, req_body, extra_headers, retry?)
  end

  # Req sets the multipart content-type — which carries the boundary — with
  # put_new_header, so the default application/json would win and the boundary
  # would never be sent. Drop it and let Req supply its own.
  defp body_options({:form_multipart, fields}, headers) do
    [headers: Utils.drop_header(headers, "content-type"), form_multipart: fields]
  end

  # Req turns a GET with a body into a POST, and an empty binary counts as a body.
  # do_get/3 and do_delete/3 pass "" for "no body", so drop it rather than send it.
  defp body_options("", headers), do: [headers: headers]

  defp body_options(req_body, headers), do: [headers: headers, body: req_body]

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
