defmodule Auth0Client.TokenStateTest do
  # Not async, and it must not be. TokenState is a single named process shared by
  # the whole suite, and the fetch runs in a Task — a *different* process from the
  # test — so the Req stub has to be in global mode for the Task to see it. Only a
  # non-async case gets that from set_req_test_from_context.
  use ExUnit.Case, async: false
  use Auth0Client.ReqCase

  alias Auth0Client.TokenState

  setup do
    original = %{
      mgmt_token: Application.get_env(:auth0_client, :mgmt_token),
      token_refresh_skew: Application.get_env(:auth0_client, :token_refresh_skew)
    }

    Application.delete_env(:auth0_client, :mgmt_token)
    Application.put_env(:auth0_client, :mgmt_client_id, "a_client_id")
    Application.put_env(:auth0_client, :mgmt_client_secret, "a_client_secret")
    TokenState.invalidate()

    on_exit(fn ->
      Enum.each(original, fn
        {key, nil} -> Application.delete_env(:auth0_client, key)
        {key, value} -> Application.put_env(:auth0_client, key, value)
      end)

      Application.delete_env(:auth0_client, :mgmt_client_id)
      Application.delete_env(:auth0_client, :mgmt_client_secret)
      TokenState.invalidate()
    end)

    :ok
  end

  describe "fetch/0" do
    test "fetches a token when the cache is empty" do
      token = build_jwt(unix_from_now(3600))
      stub_request(%{"access_token" => token})

      assert {:ok, ^token} = TokenState.fetch()

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/oauth/token"

      assert request.body["grant_type"] == "client_credentials"
      assert request.body["audience"] == "https://brighterlink.auth0.com/api/v2/"
    end

    test "reuses a cached token rather than fetching again" do
      token = build_jwt(unix_from_now(3600))
      stub_request(%{"access_token" => token})

      assert {:ok, ^token} = TokenState.fetch()
      assert_receive_request()

      assert {:ok, ^token} = TokenState.fetch()
      refute_receive {:request, _}
    end

    test "returns an error when Auth0 rejects the credentials" do
      stub_json(401, %{"error" => "access_denied"})

      assert {:error, %{reason: :token_fetch_failed, status: 401}} = TokenState.fetch()
    end

    test "returns an error when the response carries no access_token" do
      stub_request(%{"error" => "access_denied"})

      assert {:error, %{reason: :missing_access_token}} = TokenState.fetch()
    end

    test "returns an error when the request fails at the transport level" do
      Req.Test.stub(Auth0Client.Api, fn conn -> Req.Test.transport_error(conn, :econnrefused) end)

      assert {:error, %{reason: :econnrefused}} = TokenState.fetch()
    end

    test "returns an error when the issued token is not a decodable JWT" do
      stub_request(%{"access_token" => "not-a-jwt"})

      assert {:error, %{reason: :malformed_token}} = TokenState.fetch()
    end

    test "a failed fetch is not cached, so the next call tries again" do
      stub_json(500)
      assert {:error, _} = TokenState.fetch()
      assert_receive_request()

      token = build_jwt(unix_from_now(3600))
      stub_request(%{"access_token" => token})

      assert {:ok, ^token} = TokenState.fetch()
    end
  end

  describe "single-flight" do
    test "concurrent callers on a cold cache produce exactly one token request" do
      token = build_jwt(unix_from_now(3600))
      test_pid = self()

      Req.Test.stub(Auth0Client.Api, fn conn ->
        send(test_pid, :token_request)
        # Hold the request open long enough that every caller has arrived and had
        # to queue behind this one.
        Process.sleep(50)
        Req.Test.json(conn, %{"access_token" => token})
      end)

      results =
        1..20
        |> Task.async_stream(fn _ -> TokenState.fetch() end, max_concurrency: 20)
        |> Enum.map(fn {:ok, result} -> result end)

      assert Enum.all?(results, &(&1 == {:ok, token}))

      assert_receive :token_request
      refute_receive :token_request, 100
    end

    test "a failure is delivered to every waiter" do
      test_pid = self()

      Req.Test.stub(Auth0Client.Api, fn conn ->
        send(test_pid, :token_request)
        Process.sleep(50)
        conn |> Plug.Conn.put_status(429) |> Req.Test.json(%{"error" => "too_many_requests"})
      end)

      results =
        1..10
        |> Task.async_stream(fn _ -> TokenState.fetch() end, max_concurrency: 10)
        |> Enum.map(fn {:ok, result} -> result end)

      assert Enum.all?(results, &match?({:error, %{status: 429}}, &1))

      assert_receive :token_request
      refute_receive :token_request, 100
    end

    test "the process still serves requests after a failed fetch" do
      stub_json(500)
      assert {:error, _} = TokenState.fetch()
      assert_receive_request()

      token = build_jwt(unix_from_now(3600))
      stub_request(%{"access_token" => token})

      assert {:ok, ^token} = TokenState.fetch()
      assert Process.alive?(Process.whereis(TokenState))
    end
  end

  describe "expiry skew" do
    test "a token expiring inside the skew window is renewed early" do
      Application.put_env(:auth0_client, :token_refresh_skew, 300)

      # Valid for another 60 seconds, but inside the 300 second margin.
      expiring = build_jwt(unix_from_now(60))
      stub_request(%{"access_token" => expiring})
      assert {:ok, ^expiring} = TokenState.fetch()
      assert_receive_request()

      fresh = build_jwt(unix_from_now(3600))
      stub_request(%{"access_token" => fresh})

      assert {:ok, ^fresh} = TokenState.fetch()
      assert_receive_request()
    end

    test "a token expiring outside the skew window is reused" do
      Application.put_env(:auth0_client, :token_refresh_skew, 30)

      token = build_jwt(unix_from_now(3600))
      stub_request(%{"access_token" => token})
      assert {:ok, ^token} = TokenState.fetch()
      assert_receive_request()

      assert {:ok, ^token} = TokenState.fetch()
      refute_receive {:request, _}
    end

    test "an already-expired token is renewed" do
      stale = build_jwt(unix_from_now(-10))
      stub_request(%{"access_token" => stale})
      assert {:ok, ^stale} = TokenState.fetch()
      assert_receive_request()

      fresh = build_jwt(unix_from_now(3600))
      stub_request(%{"access_token" => fresh})

      assert {:ok, ^fresh} = TokenState.fetch()
    end
  end

  describe "invalidate/0" do
    test "discards the cached token so the next fetch renews it" do
      token = build_jwt(unix_from_now(3600))
      stub_request(%{"access_token" => token})
      assert {:ok, ^token} = TokenState.fetch()
      assert_receive_request()

      assert :ok = TokenState.invalidate()

      fresh = build_jwt(unix_from_now(3600))
      stub_request(%{"access_token" => fresh})

      assert {:ok, ^fresh} = TokenState.fetch()
      assert_receive_request()
    end

    test "is safe to call with nothing cached" do
      assert :ok = TokenState.invalidate()
      assert :ok = TokenState.invalidate()
    end
  end

  describe "inspect" do
    test "does not expose the token" do
      token = build_jwt(unix_from_now(3600))
      stub_request(%{"access_token" => token})
      assert {:ok, ^token} = TokenState.fetch()

      inspected = TokenState |> Process.whereis() |> :sys.get_state() |> inspect()

      refute inspected =~ token
      assert inspected =~ "REDACTED"
    end
  end
end
