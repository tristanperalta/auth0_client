defmodule Auth0Client.UtilsTest do
  # Not async: mutates application env and the globally-named TokenState agent.
  use ExUnit.Case, async: false
  use Auth0Client.ReqCase

  alias Auth0Client.TokenState
  alias Auth0Client.Utils

  setup do
    original = %{
      mgmt_token: Application.get_env(:auth0_client, :mgmt_token),
      mgmt_client_id: Application.get_env(:auth0_client, :mgmt_client_id),
      mgmt_client_secret: Application.get_env(:auth0_client, :mgmt_client_secret),
      user_agent: Application.get_env(:auth0_client, :user_agent),
      http_opts: Application.get_env(:auth0_client, :http_opts)
    }

    TokenState.invalidate()

    on_exit(fn ->
      Enum.each(original, fn
        {key, nil} -> Application.delete_env(:auth0_client, key)
        {key, value} -> Application.put_env(:auth0_client, key, value)
      end)

      TokenState.invalidate()
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
      assert Utils.http_opts() == Application.get_env(:auth0_client, :http_opts)
    end

    test "ua reads the configured user agent" do
      Application.put_env(:auth0_client, :user_agent, "MyAgent <http://example.com>")

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

  describe "drop_header/2" do
    test "removes a header by name" do
      assert [{"B", "2"}] == Utils.drop_header([{"A", "1"}, {"B", "2"}], "A")
    end

    test "matches case-insensitively" do
      assert [] == Utils.drop_header([{"Content-Type", "application/json"}], "content-type")
      assert [] == Utils.drop_header([{"content-type", "application/json"}], "Content-Type")
    end

    test "removes every occurrence" do
      assert [] == Utils.drop_header([{"A", "1"}, {"a", "2"}], "A")
    end

    test "leaves the list alone when the header is absent" do
      headers = [{"A", "1"}]

      assert headers == Utils.drop_header(headers, "B")
    end
  end

  describe "normalize_permissions/1" do
    test "expands a tuple into the documented map" do
      assert [%{resource_server_identifier: "https://api", permission_name: "read:users"}] ==
               Utils.normalize_permissions([{"https://api", "read:users"}])
    end

    test "passes an atom-keyed map through untouched" do
      permission = %{resource_server_identifier: "https://api", permission_name: "read:users"}

      assert [permission] == Utils.normalize_permissions([permission])
    end

    test "passes a string-keyed map through, so Auth0's own output round-trips" do
      permission = %{
        "resource_server_identifier" => "https://api",
        "permission_name" => "read:users"
      }

      assert [permission] == Utils.normalize_permissions([permission])
    end

    test "handles a mixed list" do
      assert [%{resource_server_identifier: "https://api", permission_name: "a"}, %{"x" => "y"}] ==
               Utils.normalize_permissions([{"https://api", "a"}, %{"x" => "y"}])
    end

    test "an empty list stays empty" do
      assert [] == Utils.normalize_permissions([])
    end
  end

  describe "request_headers/2" do
    test ":mgmt prepends a bearer token" do
      Application.put_env(:auth0_client, :mgmt_token, "STATIC")

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
      Application.put_env(:auth0_client, :mgmt_token, "STATIC")

      assert {:ok, headers} = Utils.request_headers(:mgmt, [{"Authorization", "Bearer OTHER"}])

      assert Enum.count(headers, &match?({"Authorization", _}, &1)) == 1
      assert {"Authorization", "Bearer OTHER"} in headers
    end

    test "propagates a token fetch failure" do
      Application.delete_env(:auth0_client, :mgmt_token)
      Application.put_env(:auth0_client, :mgmt_client_id, "a_client_id")
      Application.put_env(:auth0_client, :mgmt_client_secret, "a_client_secret")

      stub_json(429, %{"error" => "too_many_requests"})

      assert {:error, %{reason: :token_fetch_failed, status: 429}} = Utils.request_headers(:mgmt)
    end
  end

  # Fetching and caching live in Auth0Client.TokenState; see its test for that
  # behaviour. Utils only decides where a token comes from.
  describe "mgmt_token/0" do
    test "returns a statically configured token without any http call" do
      Application.put_env(:auth0_client, :mgmt_token, "STATIC")

      assert {:ok, "STATIC"} == Utils.mgmt_token()
      refute_receive {:request, _}
    end

    test "a statically configured token is never cached" do
      Application.put_env(:auth0_client, :mgmt_token, "STATIC")
      Utils.mgmt_token()

      # Nothing was cached, so with the static token removed there is nothing to
      # fall back on and a fetch has to happen.
      Application.delete_env(:auth0_client, :mgmt_token)
      Application.put_env(:auth0_client, :mgmt_client_id, "a_client_id")
      Application.put_env(:auth0_client, :mgmt_client_secret, "a_client_secret")

      fresh = build_jwt(unix_from_now(3600))
      stub_request(%{"access_token" => fresh})

      assert {:ok, ^fresh} = Utils.mgmt_token()
    end

    test "delegates to the token cache when no static token is configured" do
      Application.delete_env(:auth0_client, :mgmt_token)
      Application.put_env(:auth0_client, :mgmt_client_id, "a_client_id")
      Application.put_env(:auth0_client, :mgmt_client_secret, "a_client_secret")

      token = build_jwt(unix_from_now(3600))
      stub_request(%{"access_token" => token})

      assert {:ok, ^token} = Utils.mgmt_token()
      assert assert_receive_request().path == "/oauth/token"
    end
  end
end
