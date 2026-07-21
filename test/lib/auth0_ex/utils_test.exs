defmodule Auth0Ex.UtilsTest do
  # Not async: mutates application env and the globally-named TokenState agent.
  use ExUnit.Case, async: false
  use Auth0Ex.ReqCase

  alias Auth0Ex.TokenState
  alias Auth0Ex.Utils

  setup do
    original = %{
      mgmt_token: Application.get_env(:auth0_ex, :mgmt_token),
      mgmt_client_id: Application.get_env(:auth0_ex, :mgmt_client_id),
      mgmt_client_secret: Application.get_env(:auth0_ex, :mgmt_client_secret),
      user_agent: Application.get_env(:auth0_ex, :user_agent),
      http_opts: Application.get_env(:auth0_ex, :http_opts)
    }

    TokenState.put(:mgmt_token, nil)
    TokenState.put(:exp, nil)

    on_exit(fn ->
      Enum.each(original, fn
        {key, nil} -> Application.delete_env(:auth0_ex, key)
        {key, value} -> Application.put_env(:auth0_ex, key, value)
      end)

      TokenState.put(:mgmt_token, nil)
      TokenState.put(:exp, nil)
    end)

    :ok
  end

  describe "base_url/0,1" do
    test "builds the tenant url with a trailing slash" do
      assert "https://brighterlink.auth0.com/" == Utils.base_url()
    end

    test ":mgmt appends the v2 api prefix" do
      assert "https://brighterlink.auth0.com/api/v2/" == Utils.base_url(:mgmt)
    end

    test "any other tag falls back to the plain tenant url" do
      assert Utils.base_url() == Utils.base_url(nil)
      assert Utils.base_url() == Utils.base_url(:auth)
    end
  end

  describe "oauth_url/0" do
    test "points at the token endpoint" do
      assert "https://brighterlink.auth0.com/oauth/token" == Utils.oauth_url()
    end
  end

  describe "http_opts/0 and ua/0" do
    test "http_opts reads from config" do
      assert Utils.http_opts() == Application.get_env(:auth0_ex, :http_opts)
    end

    test "ua reads the configured user agent" do
      Application.put_env(:auth0_ex, :user_agent, "MyAgent <http://example.com>")

      assert "MyAgent <http://example.com>" == Utils.ua()
    end
  end

  describe "base_headers/0" do
    test "sets the user agent and json content type" do
      headers = Utils.base_headers()

      assert {"Content-Type", "application/json"} in headers
      assert {"User-Agent", Utils.ua()} in headers
    end
  end

  describe "merge_headers/2" do
    test "returns the base unchanged when there is nothing to merge" do
      base = [{"A", "1"}]

      assert base == Utils.merge_headers(base, [])
    end

    test "appends headers that do not collide" do
      assert [{"A", "1"}, {"B", "2"}] == Utils.merge_headers([{"A", "1"}], [{"B", "2"}])
    end

    test "extra wins on a duplicate name" do
      assert [{"A", "2"}] == Utils.merge_headers([{"A", "1"}], [{"A", "2"}])
    end

    test "duplicate names are matched case-insensitively" do
      assert [{"authorization", "new"}] ==
               Utils.merge_headers([{"Authorization", "old"}], [{"authorization", "new"}])
    end
  end

  describe "request_headers/2" do
    test ":mgmt prepends a bearer token" do
      Application.put_env(:auth0_ex, :mgmt_token, "STATIC")

      assert {:ok, [{"Authorization", "Bearer STATIC"} | rest]} = Utils.request_headers(:mgmt)
      assert rest == Utils.base_headers()
    end

    test "any other tag omits the authorization header" do
      assert {:ok, headers} = Utils.request_headers(nil)
      assert headers == Utils.base_headers()

      assert {:ok, auth_headers} = Utils.request_headers(:auth)
      refute Enum.any?(auth_headers, &match?({"Authorization", _}, &1))
    end

    test "merges extra headers over the defaults" do
      assert {:ok, headers} = Utils.request_headers(nil, [{"Authorization", "Bearer USER"}])

      assert {"Authorization", "Bearer USER"} in headers
      assert {"Content-Type", "application/json"} in headers
    end

    test "an extra authorization replaces the management token rather than duplicating it" do
      Application.put_env(:auth0_ex, :mgmt_token, "STATIC")

      assert {:ok, headers} = Utils.request_headers(:mgmt, [{"Authorization", "Bearer OTHER"}])

      assert Enum.count(headers, &match?({"Authorization", _}, &1)) == 1
      assert {"Authorization", "Bearer OTHER"} in headers
    end

    test "propagates a token fetch failure" do
      Application.delete_env(:auth0_ex, :mgmt_token)
      Application.put_env(:auth0_ex, :mgmt_client_id, "a_client_id")
      Application.put_env(:auth0_ex, :mgmt_client_secret, "a_client_secret")

      stub_request(fn conn ->
        conn |> Plug.Conn.put_status(429) |> Req.Test.json(%{"error" => "too_many_requests"})
      end)

      assert {:error, %{reason: :token_fetch_failed, status: 429}} = Utils.request_headers(:mgmt)
    end
  end

  describe "mgmt_token/0 with a statically configured token" do
    test "returns the configured token without any http call" do
      Application.put_env(:auth0_ex, :mgmt_token, "STATIC")

      assert {:ok, "STATIC"} == Utils.mgmt_token()
      refute_receive {:request, _}
    end

    test "does not populate the token cache" do
      Application.put_env(:auth0_ex, :mgmt_token, "STATIC")
      Utils.mgmt_token()

      assert nil == TokenState.get(:mgmt_token)
    end
  end

  describe "mgmt_token/0 with client credentials" do
    setup do
      Application.delete_env(:auth0_ex, :mgmt_token)
      Application.put_env(:auth0_ex, :mgmt_client_id, "a_client_id")
      Application.put_env(:auth0_ex, :mgmt_client_secret, "a_client_secret")
      :ok
    end

    test "fetches a token when the cache is empty" do
      token = build_jwt(unix_from_now(3600))
      stub_request(%{"access_token" => token})

      assert {:ok, ^token} = Utils.mgmt_token()

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/oauth/token"

      assert request.body == %{
               "client_id" => "a_client_id",
               "client_secret" => "a_client_secret",
               "audience" => "https://brighterlink.auth0.com/api/v2/",
               "grant_type" => "client_credentials"
             }
    end

    test "caches the token and its expiry" do
      exp = unix_from_now(3600)
      token = build_jwt(exp)
      stub_request(%{"access_token" => token})

      Utils.mgmt_token()

      assert token == TokenState.get(:mgmt_token)
      assert exp == TokenState.get(:exp)
    end

    test "reuses a cached token that has not expired" do
      TokenState.put(:mgmt_token, "cached_token")
      TokenState.put(:exp, unix_from_now(3600))

      assert {:ok, "cached_token"} == Utils.mgmt_token()
      refute_receive {:request, _}
    end

    test "refetches when the cached token has expired" do
      TokenState.put(:mgmt_token, "stale_token")
      TokenState.put(:exp, unix_from_now(-10))

      fresh = build_jwt(unix_from_now(3600))
      stub_request(%{"access_token" => fresh})

      assert {:ok, ^fresh} = Utils.mgmt_token()
      assert fresh == TokenState.get(:mgmt_token)
    end

    test "refetches when a cached token has no recorded expiry" do
      TokenState.put(:mgmt_token, "cached_token")
      TokenState.put(:exp, nil)

      fresh = build_jwt(unix_from_now(3600))
      stub_request(%{"access_token" => fresh})

      assert {:ok, ^fresh} = Utils.mgmt_token()
    end

    test "returns an error when the token response has no access_token" do
      stub_request(%{"error" => "access_denied"})

      assert {:error, %{reason: :missing_access_token, body: %{"error" => "access_denied"}}} =
               Utils.mgmt_token()
    end

    test "returns an error when Auth0 rejects the credentials" do
      stub_request(fn conn ->
        conn |> Plug.Conn.put_status(401) |> Req.Test.json(%{"error" => "access_denied"})
      end)

      assert {:error, %{reason: :token_fetch_failed, status: 401, body: body}} =
               Utils.mgmt_token()

      assert body == %{"error" => "access_denied"}
    end

    test "returns an error when the token request fails at the transport level" do
      Req.Test.stub(Auth0Ex.Api, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert {:error, %{reason: :econnrefused}} = Utils.mgmt_token()
    end

    test "returns an error when the issued token is not a decodable JWT" do
      stub_request(%{"access_token" => "not-a-jwt"})

      assert {:error, %{reason: :malformed_token}} = Utils.mgmt_token()
      assert nil == TokenState.get(:mgmt_token)
    end
  end
end
