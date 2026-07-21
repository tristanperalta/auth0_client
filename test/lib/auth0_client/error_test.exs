defmodule Auth0Client.ErrorTest do
  use ExUnit.Case, async: true

  alias Auth0Client.Error

  describe "from_response/3" do
    test "derives the reason from the status" do
      assert %Error{reason: :not_found} = Error.from_response(404, %{}, %{})
      assert %Error{reason: :rate_limited} = Error.from_response(429, %{}, %{})
    end

    test "treats any 5xx as a server error" do
      for status <- [500, 502, 503, 504] do
        assert %Error{reason: :server_error} = Error.from_response(status, %{}, %{})
      end
    end

    test "falls back to :http_error for an unmapped status" do
      assert %Error{reason: :http_error} = Error.from_response(418, %{}, %{})
    end

    test "keeps the status, body and headers" do
      error = Error.from_response(401, %{"error" => "denied"}, %{"x-req-id" => ["abc"]})

      assert error.status == 401
      assert error.body == %{"error" => "denied"}
      assert error.headers == %{"x-req-id" => ["abc"]}
    end
  end

  describe "from_reason/2" do
    test "carries no status by default" do
      assert %Error{reason: :econnrefused, status: nil, headers: %{}} =
               Error.from_reason(:econnrefused)
    end

    test "accepts a status and body" do
      error = Error.from_reason(:token_fetch_failed, status: 429, body: %{"error" => "slow down"})

      assert error.status == 429
      assert error.body == %{"error" => "slow down"}
    end
  end

  describe "retry_after/1" do
    test "reads the header as seconds" do
      assert 30 == Error.retry_after(Error.from_response(429, %{}, %{"retry-after" => ["30"]}))
    end

    test "accepts a bare string value" do
      assert 5 == Error.retry_after(Error.from_response(429, %{}, %{"retry-after" => "5"}))
    end

    test "returns nil when the header is absent" do
      assert nil == Error.retry_after(Error.from_response(429, %{}, %{}))
    end

    test "returns nil for an HTTP-date value rather than guessing" do
      date = "Wed, 21 Oct 2026 07:28:00 GMT"

      assert nil == Error.retry_after(Error.from_response(429, %{}, %{"retry-after" => [date]}))
    end

    test "returns nil for a non-numeric value" do
      assert nil == Error.retry_after(Error.from_response(429, %{}, %{"retry-after" => ["soon"]}))
    end

    test "returns nil when there are no headers at all" do
      assert nil == Error.retry_after(Error.from_reason(:timeout))
    end
  end

  describe "message/1" do
    test "describes a transport failure without inventing a status" do
      message = Exception.message(Error.from_reason(:econnrefused))

      assert message =~ "econnrefused"
      refute message =~ "HTTP"
    end

    test "prefers Auth0's error_description" do
      error = Error.from_response(401, %{"error_description" => "Wrong password"}, %{})

      assert Exception.message(error) =~ "Wrong password"
      assert Exception.message(error) =~ "401"
    end

    test "falls back through message and error keys" do
      assert Exception.message(Error.from_response(400, %{"message" => "Bad"}, %{})) =~ "Bad"
      assert Exception.message(Error.from_response(400, %{"error" => "nope"}, %{})) =~ "nope"
    end

    test "handles a non-JSON body" do
      assert Exception.message(Error.from_response(502, "Bad Gateway", %{})) =~ "Bad Gateway"
    end
  end

  test "is raisable" do
    error = Error.from_response(404, %{"message" => "no such user"}, %{})

    assert_raise Auth0Client.Error, ~r/no such user/, fn -> raise error end
  end
end
