defmodule Auth0Client.Management.RefreshTokenTest do
  use ExUnit.Case, async: true
  use Auth0Client.ReqCase

  alias Auth0Client.Management.RefreshToken

  describe "all/1" do
    # The tenant-level path with user_id as a query param — not /users/{id}/refresh-tokens,
    # which is User.refresh_tokens/2.
    test "sends user_id as a query param" do
      stub_request(%{"tokens" => []})

      assert {:ok, %{"tokens" => []}} = RefreshToken.all(user_id: "auth0|23423")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/refresh-tokens"
      assert request.query == %{"user_id" => "auth0|23423"}
    end

    test "narrows to one client" do
      stub_request(%{})
      RefreshToken.all(%{user_id: "auth0|23423", client_id: "abc123", take: 50})

      assert assert_receive_request().query == %{
               "user_id" => "auth0|23423",
               "client_id" => "abc123",
               "take" => "50"
             }
    end
  end

  describe "get/1" do
    test "gets a single refresh token" do
      stub_request(%{"id" => "rt_1", "user_id" => "auth0|1"})

      assert {:ok, %{"id" => "rt_1"}} = RefreshToken.get("rt_1")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/refresh-tokens/rt_1"
    end
  end

  describe "update/2" do
    test "patches the metadata" do
      stub_request(%{"id" => "rt_1"})

      assert {:ok, _} = RefreshToken.update("rt_1", %{refresh_token_metadata: %{app: "ios"}})

      request = assert_receive_request()
      assert request.method == "PATCH"
      assert request.path == "/api/v2/refresh-tokens/rt_1"
      assert request.body == %{"refresh_token_metadata" => %{"app" => "ios"}}
    end

    test "sends an explicit null when clearing metadata" do
      stub_request(%{"id" => "rt_1"})

      assert {:ok, _} = RefreshToken.update("rt_1", %{refresh_token_metadata: nil})

      assert assert_receive_request().body == %{"refresh_token_metadata" => nil}
    end
  end

  describe "delete/1 and revoke/1" do
    test "delete/1 addresses one token by id and accepts a 202" do
      stub_request(fn conn -> Plug.Conn.send_resp(conn, 202, "") end)

      assert :ok = RefreshToken.delete("rt_1")

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/refresh-tokens/rt_1"
    end

    test "revoke/1 posts a bulk body to its own path and accepts a 202" do
      stub_request(fn conn -> Plug.Conn.send_resp(conn, 202, "") end)

      assert :ok = RefreshToken.revoke(%{ids: ["rt_1", "rt_2"]})

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/refresh-tokens/revoke"
      assert request.body == %{"ids" => ["rt_1", "rt_2"]}
    end

    test "revoke/1 accepts the user and client combination" do
      stub_request(fn conn -> Plug.Conn.send_resp(conn, 202, "") end)

      assert :ok = RefreshToken.revoke(%{user_id: "auth0|23423", client_id: "abc123"})

      assert assert_receive_request().body == %{
               "user_id" => "auth0|23423",
               "client_id" => "abc123"
             }
    end
  end
end
