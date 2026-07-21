defmodule Auth0Ex.Management.ConnectionTest do
  use ExUnit.Case, async: true
  use Auth0Ex.ReqCase

  alias Auth0Ex.Management.Connection

  describe "all/0,1" do
    test "gets all connections" do
      stub_request([%{"name" => "Username-Password-Authentication"}])

      assert {:ok, [%{"name" => "Username-Password-Authentication"}]} =
               Connection.all(%{strategy: "auth0"})

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/connections"
      assert request.query == %{"strategy" => "auth0"}
    end

    test "accepts a keyword list of params" do
      stub_request([])

      assert {:ok, []} = Connection.all(name: "some_name")

      assert assert_receive_request().query == %{"name" => "some_name"}
    end

    test "sends no params by default" do
      stub_request([])

      assert {:ok, []} = Connection.all()

      request = assert_receive_request()
      assert request.path == "/api/v2/connections"
      assert request.query_string == ""
    end
  end

  describe "get/1,2" do
    test "gets a single connection" do
      stub_request(%{"id" => "con_123"})

      assert {:ok, %{"id" => "con_123"}} = Connection.get("con_123")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/connections/con_123"
      assert request.query_string == ""
    end

    test "passes through params" do
      stub_request(%{"id" => "con_123"})

      assert {:ok, _} = Connection.get("con_123", fields: "id,name")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/connections/con_123"
      assert request.query == %{"fields" => "id,name"}
    end

    test "accepts a map of params" do
      stub_request(%{"id" => "con_123"})

      assert {:ok, _} = Connection.get("con_123", %{fields: "id", include_fields: true})

      assert assert_receive_request().query == %{
               "fields" => "id",
               "include_fields" => "true"
             }
    end
  end

  describe "create/1" do
    test "posts the body" do
      stub_request(%{"name" => "some_name"})

      assert {:ok, %{"name" => "some_name"}} =
               Connection.create(%{name: "some_name", strategy: "email"})

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/connections"
      assert request.body == %{"name" => "some_name", "strategy" => "email"}
    end
  end

  describe "update/2" do
    test "patches the body" do
      stub_request(%{"name" => "new name"})

      assert {:ok, _} = Connection.update("con_123", %{name: "new name"})

      request = assert_receive_request()
      assert request.method == "PATCH"
      assert request.path == "/api/v2/connections/con_123"
      assert request.body == %{"name" => "new name"}
    end
  end

  describe "delete/1" do
    test "deletes and returns :ok on 204" do
      stub_request(fn conn -> Plug.Conn.send_resp(conn, 204, "") end)

      assert :ok = Connection.delete("con_123")

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/connections/con_123"
      assert request.query_string == ""
    end
  end

  describe "delete_conn_user/2" do
    test "deletes the user by email" do
      stub_request(fn conn -> Plug.Conn.send_resp(conn, 204, "") end)

      assert :ok = Connection.delete_conn_user("con_123", "samar@example.com")

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/connections/con_123/users"
      assert request.query == %{"email" => "samar@example.com"}
    end
  end
end
