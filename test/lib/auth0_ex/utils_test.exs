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

  describe "req_header/0" do
    test "sets the user agent and json content type" do
      headers = Utils.req_header()

      assert {"Content-Type", "application/json"} in headers
      assert {"User-Agent", Utils.ua()} in headers
    end
  end

  describe "req_header/1" do
    test ":mgmt prepends a bearer token" do
      Application.put_env(:auth0_ex, :mgmt_token, "STATIC")

      assert [{"Authorization", "Bearer STATIC"} | rest] = Utils.req_header(:mgmt)
      assert rest == Utils.req_header()
    end

    test "any other tag omits the authorization header" do
      assert Utils.req_header() == Utils.req_header(nil)
      refute Enum.any?(Utils.req_header(:auth), &match?({"Authorization", _}, &1))
    end
  end

  describe "mgmt_token/0 with a statically configured token" do
    test "returns the configured token without any http call" do
      Application.put_env(:auth0_ex, :mgmt_token, "STATIC")

      assert "STATIC" == Utils.mgmt_token()
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

      assert token == Utils.mgmt_token()

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

      assert "cached_token" == Utils.mgmt_token()
      refute_receive {:request, _}
    end

    test "refetches when the cached token has expired" do
      TokenState.put(:mgmt_token, "stale_token")
      TokenState.put(:exp, unix_from_now(-10))

      fresh = build_jwt(unix_from_now(3600))
      stub_request(%{"access_token" => fresh})

      assert fresh == Utils.mgmt_token()
      assert fresh == TokenState.get(:mgmt_token)
    end

    test "raises when the token response has no access_token" do
      stub_request(%{"error" => "access_denied"})

      assert_raise MatchError, fn -> Utils.mgmt_token() end
    end

    test "raises when the token request fails at the transport level" do
      Req.Test.stub(Auth0Ex.Api, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert_raise MatchError, fn -> Utils.mgmt_token() end
    end
  end
end
