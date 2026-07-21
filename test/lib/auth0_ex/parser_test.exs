defmodule Auth0Ex.ParserTest do
  use ExUnit.Case, async: true

  alias Auth0Ex.Parser

  defp response(status, body), do: {:ok, %Req.Response{status: status, body: body}}

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
    test "4xx returns the decoded body and status" do
      body = %{"statusCode" => 401, "error" => "Unauthorized", "message" => "Bad token"}

      assert {:error, ^body, 401} = Parser.parse(response(401, body))
    end

    test "5xx returns the decoded body and status" do
      assert {:error, %{"error" => "boom"}, 500} =
               Parser.parse(response(500, %{"error" => "boom"}))
    end

    test "a non-JSON error body is passed through untouched" do
      assert {:error, "Bad Gateway", 502} = Parser.parse(response(502, "Bad Gateway"))
    end

    test "3xx is treated as an error" do
      assert {:error, "", 301} = Parser.parse(response(301, ""))
    end
  end

  describe "transport and protocol failures" do
    test "transport errors surface the reason" do
      assert {:error, %{reason: :econnrefused}} =
               Parser.parse({:error, %Req.TransportError{reason: :econnrefused}})
    end

    test "timeouts surface the reason" do
      assert {:error, %{reason: :timeout}} =
               Parser.parse({:error, %Req.TransportError{reason: :timeout}})
    end

    test "HTTP protocol errors surface the reason" do
      assert {:error, %{reason: :unprocessed}} =
               Parser.parse({:error, %Req.HTTPError{protocol: :http2, reason: :unprocessed}})
    end

    test "an unrecognised exception degrades to its message" do
      assert {:error, %{reason: reason}} = Parser.parse({:error, %ArgumentError{message: "nope"}})
      assert reason =~ "nope"
    end
  end
end
