defmodule Auth0Client.Management.Connection.ScimTest do
  use ExUnit.Case, async: true
  use Auth0Client.ReqCase

  alias Auth0Client.Management.Connection.Scim

  describe "all/1" do
    # The tenant-wide listing lives at its own top-level path, not under a connection.
    test "hits the tenant-level path" do
      stub_request(%{"scim_configurations" => []})

      assert {:ok, %{"scim_configurations" => []}} = Scim.all()

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/connections-scim-configurations"
      assert request.query_string == ""
    end

    test "supports checkpoint pagination" do
      stub_request(%{})
      Scim.all(from: "abc", take: 50)

      assert assert_receive_request().query == %{"from" => "abc", "take" => "50"}
    end
  end

  describe "get/1" do
    test "gets the configuration for a connection" do
      stub_request(%{"connection_id" => "con_123", "user_id_attribute" => "externalId"})

      assert {:ok, %{"connection_id" => "con_123"}} = Scim.get("con_123")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/connections/con_123/scim-configuration"
    end
  end

  describe "create/2" do
    test "posts the configuration and accepts a 201" do
      stub_request(fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(201, ~s({"connection_id":"con_123"}))
      end)

      assert {:ok, %{"connection_id" => "con_123"}} =
               Scim.create("con_123", %{
                 user_id_attribute: "externalId",
                 mapping: [%{auth0: "email", scim: "userName"}]
               })

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/connections/con_123/scim-configuration"

      assert request.body == %{
               "user_id_attribute" => "externalId",
               "mapping" => [%{"auth0" => "email", "scim" => "userName"}]
             }
    end

    test "defaults to an empty body" do
      stub_request(fn conn -> Plug.Conn.send_resp(conn, 201, "") end)

      assert :ok = Scim.create("con_123")

      assert assert_receive_request().body == %{}
    end
  end

  describe "update/2" do
    test "patches the configuration" do
      stub_request(%{"connection_id" => "con_123"})

      assert {:ok, _} =
               Scim.update("con_123", %{
                 user_id_attribute: "externalId",
                 mapping: [%{auth0: "email", scim: "userName"}]
               })

      request = assert_receive_request()
      assert request.method == "PATCH"
      assert request.path == "/api/v2/connections/con_123/scim-configuration"
      assert request.body["user_id_attribute"] == "externalId"
    end
  end

  describe "delete/1" do
    test "deletes and returns :ok on 204" do
      stub_request(fn conn -> Plug.Conn.send_resp(conn, 204, "") end)

      assert :ok = Scim.delete("con_123")

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/connections/con_123/scim-configuration"
    end
  end

  describe "default_mapping/1" do
    test "gets the default mapping" do
      stub_request(%{"mapping" => []})

      assert {:ok, %{"mapping" => []}} = Scim.default_mapping("con_123")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/connections/con_123/scim-configuration/default-mapping"
    end
  end

  describe "tokens" do
    test "tokens/1 lists them" do
      stub_request([%{"token_id" => "tok_1"}])

      assert {:ok, [%{"token_id" => "tok_1"}]} = Scim.tokens("con_123")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/connections/con_123/scim-configuration/tokens"
    end

    test "create_token/2 posts scopes and accepts a 201" do
      stub_request(fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(201, ~s({"token":"secret","token_id":"tok_1"}))
      end)

      assert {:ok, %{"token" => "secret"}} =
               Scim.create_token("con_123", %{scopes: ["get:users"], token_lifetime: 86_400})

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/connections/con_123/scim-configuration/tokens"
      assert request.body == %{"scopes" => ["get:users"], "token_lifetime" => 86_400}
    end

    test "delete_token/2 addresses the token by id" do
      stub_request(fn conn -> Plug.Conn.send_resp(conn, 204, "") end)

      assert :ok = Scim.delete_token("con_123", "tok_1")

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/connections/con_123/scim-configuration/tokens/tok_1"
    end
  end
end
