defmodule Auth0Ex.ReqCase do
  @moduledoc """
  Shared helpers for tests that exercise the HTTP layer.

  Stubs are registered against the `Auth0Ex.Api` name, which `config/test.exs`
  wires up via `http_opts: [plug: {Req.Test, Auth0Ex.Api}]`.

  `use Auth0Ex.ReqCase` alongside `use ExUnit.Case`; it only adds the Req.Test
  setup callbacks and imports these helpers. Ownership is per-process, so cases
  that touch no other global state may run `async: true`.
  """

  defmacro __using__(_opts) do
    quote do
      import Auth0Ex.ReqCase

      setup {Req.Test, :set_req_test_from_context}
      setup {Req.Test, :verify_on_exit!}
    end
  end

  @doc """
  Captures the request a call makes and replies with `response`.

  Sends the received `Plug.Conn` back to the test process so it can be awaited
  with `assert_receive_request/0`, letting a test assert on the method, path,
  query string and body that were actually sent.

  `response` may be a function taking the conn, or a term to send as JSON:

      stub_request(%{"client_id" => "abc"})
      stub_request(fn conn -> Plug.Conn.send_resp(conn, 204, "") end)
  """
  def stub_request(response) do
    test_pid = self()

    Req.Test.stub(Auth0Ex.Api, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      send(test_pid, {:request, describe(conn, body)})

      case response do
        fun when is_function(fun, 1) -> fun.(conn)
        term -> Req.Test.json(conn, term)
      end
    end)
  end

  @doc """
  Returns the request captured by `stub_request/1`.
  """
  defmacro assert_receive_request do
    quote do
      assert_receive {:request, captured_request}
      captured_request
    end
  end

  @doc """
  Builds a structurally valid JWT whose payload carries the given `exp`.

  `Auth0Ex.Utils` decodes the middle segment to read expiry, so tokens handed to
  it must really be three base64url segments, not an opaque string.
  """
  def build_jwt(exp) do
    header = encode_segment(%{"alg" => "HS256", "typ" => "JWT"})
    payload = encode_segment(%{"exp" => exp})
    "#{header}.#{payload}.signature"
  end

  @doc """
  A unix timestamp `seconds` from now. Pass a negative value for the past.
  """
  def unix_from_now(seconds) do
    DateTime.utc_now() |> DateTime.to_unix() |> Kernel.+(seconds)
  end

  defp encode_segment(map) do
    map |> Jason.encode!() |> Base.url_encode64(padding: false)
  end

  defp describe(conn, body) do
    %{
      method: conn.method,
      path: conn.request_path,
      query: URI.decode_query(conn.query_string),
      query_string: conn.query_string,
      headers: conn.req_headers,
      content_type: content_type(conn),
      body: decode_body(body, content_type(conn))
    }
  end

  defp content_type(conn) do
    conn
    |> Plug.Conn.get_req_header("content-type")
    |> List.first()
    |> case do
      nil -> nil
      value -> value |> String.split(";", parts: 2) |> hd() |> String.trim()
    end
  end

  defp decode_body("", _content_type), do: ""

  # Decoded by the content type the request actually declared, so a test asserting
  # on `body` sees the same structure regardless of which encoding the endpoint uses.
  defp decode_body(body, "application/x-www-form-urlencoded"), do: URI.decode_query(body)

  defp decode_body(body, _content_type) do
    case Jason.decode(body) do
      {:ok, decoded} -> decoded
      {:error, _} -> body
    end
  end
end
