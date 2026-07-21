defmodule Auth0Ex.ParserTest do
  use ExUnit.Case, async: true

  alias Auth0Ex.Error
  alias Auth0Ex.Parser

  defp response(status, body, headers \\ %{}),
    do: {:ok, %Req.Response{status: status, body: body, headers: headers}}

  describe "successful responses" do
    test "200 returns the decoded body" do
      assert {:ok, %{"name" => "app"}} = Parser.parse(response(200, %{"name" => "app"}))
    end

    test "201 returns the decoded body" do
      assert {:ok, %{"id" => "1"}} = Parser.parse(response(201, %{"id" => "1"}))
    end

    test "a decoded list body is returned as-is" do
      assert {:ok, [%{"id" => "1"}]} = Parser.parse(response(200, [%{"id" => "1"}]))
    end

    test "a non-JSON body is passed through untouched" do
      assert {:ok, "<html>hello</html>"} = Parser.parse(response(200, "<html>hello</html>"))
    end

    test "204 discards the body and returns :ok" do
      assert :ok = Parser.parse(response(204, ""))
    end
  end

  describe "error responses" do
    test "4xx returns an error carrying the decoded body and status" do
      body = %{"statusCode" => 401, "error" => "Unauthorized", "message" => "Bad token"}

      assert {:error, %Error{reason: :unauthorized, status: 401, body: ^body}} =
               Parser.parse(response(401, body))
    end

    test "5xx returns an error carrying the decoded body and status" do
      assert {:error, %Error{reason: :server_error, status: 500, body: %{"error" => "boom"}}} =
               Parser.parse(response(500, %{"error" => "boom"}))
    end

    test "a non-JSON error body is passed through untouched" do
      assert {:error, %Error{status: 502, body: "Bad Gateway"}} =
               Parser.parse(response(502, "Bad Gateway"))
    end

    test "3xx is treated as an error" do
      assert {:error, %Error{reason: :http_error, status: 301}} = Parser.parse(response(301, ""))
    end

    test "the reason is derived from the status" do
      for {status, reason} <- [
            {400, :bad_request},
            {401, :unauthorized},
            {403, :forbidden},
            {404, :not_found},
            {409, :conflict},
            {429, :rate_limited},
            {503, :server_error}
          ] do
        assert {:error, %Error{reason: ^reason}} = Parser.parse(response(status, %{}))
      end
    end
  end

  describe "response headers" do
    test "are carried onto the error" do
      headers = %{"retry-after" => ["30"], "content-type" => ["application/json"]}

      assert {:error, %Error{headers: ^headers}} = Parser.parse(response(429, %{}, headers))
    end

    test "make Retry-After reachable on a rate-limited response" do
      {:error, error} = Parser.parse(response(429, %{}, %{"retry-after" => ["30"]}))

      assert error.reason == :rate_limited
      assert Error.retry_after(error) == 30
    end

    test "are empty rather than nil when a transport failure produced none" do
      assert {:error, %Error{headers: %{}}} =
               Parser.parse({:error, %Req.TransportError{reason: :timeout}})
    end
  end

  describe "transport and protocol failures" do
    test "transport errors surface the reason and carry no status" do
      assert {:error, %Error{reason: :econnrefused, status: nil}} =
               Parser.parse({:error, %Req.TransportError{reason: :econnrefused}})
    end

    test "timeouts surface the reason" do
      assert {:error, %Error{reason: :timeout}} =
               Parser.parse({:error, %Req.TransportError{reason: :timeout}})
    end

    test "HTTP protocol errors surface the reason" do
      assert {:error, %Error{reason: :unprocessed}} =
               Parser.parse({:error, %Req.HTTPError{protocol: :http2, reason: :unprocessed}})
    end

    test "an unrecognised exception degrades to its message" do
      assert {:error, %Error{reason: :request_failed, body: body}} =
               Parser.parse({:error, %ArgumentError{message: "nope"}})

      assert body =~ "nope"
    end

    test "an error that is already an Auth0Ex.Error passes through unchanged" do
      error = Error.from_reason(:token_fetch_failed, status: 429)

      assert {:error, ^error} = Parser.parse({:error, error})
    end
  end
end
