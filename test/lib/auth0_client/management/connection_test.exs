defmodule Auth0Client.Management.ConnectionTest do
  use ExUnit.Case, async: true
  use Auth0Client.ReqCase

  alias Auth0Client.Management.Connection

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
      stub_status(204)

      assert :ok = Connection.delete("con_123")

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/connections/con_123"
      assert request.query_string == ""
    end
  end

  describe "delete_conn_user/2" do
    test "deletes the user by email" do
      stub_status(204)

      assert :ok = Connection.delete_conn_user("con_123", "samar@example.com")

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/connections/con_123/users"
      assert request.query == %{"email" => "samar@example.com"}
    end
  end

  describe "clients/2" do
    test "lists the clients with this connection enabled" do
      stub_request(%{"clients" => [%{"client_id" => "abc123"}]})

      assert {:ok, %{"clients" => _}} = Connection.clients("con_123")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/connections/con_123/clients"
      assert request.query_string == ""
    end

    test "supports checkpoint pagination" do
      stub_request(%{})
      Connection.clients("con_123", from: "abc", take: 50)

      assert assert_receive_request().query == %{"from" => "abc", "take" => "50"}
    end
  end

  describe "update_clients/2" do
    # The body is a JSON array, not an object. do_patch reads a *keyword* list as an
    # object, so a list of maps has to survive untouched — it used to raise.
    test "sends an array of client statuses and returns :ok on 204" do
      stub_status(204)

      assert :ok =
               Connection.update_clients("con_123", [
                 %{client_id: "abc123", status: true},
                 %{client_id: "def456", status: false}
               ])

      request = assert_receive_request()
      assert request.method == "PATCH"
      assert request.path == "/api/v2/connections/con_123/clients"

      assert request.body == [
               %{"client_id" => "abc123", "status" => true},
               %{"client_id" => "def456", "status" => false}
             ]
    end
  end

  describe "connection keys" do
    test "keys/1 gets them" do
      stub_request([%{"kid" => "abc"}])

      assert {:ok, [%{"kid" => "abc"}]} = Connection.keys("con_123")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/connections/con_123/keys"
    end

    test "create_keys/2 posts and accepts a 201" do
      stub_json(201, %{"kid" => "abc"})

      assert {:ok, %{"kid" => "abc"}} = Connection.create_keys("con_123", %{signing_alg: "RS256"})

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/connections/con_123/keys"
      assert request.body == %{"signing_alg" => "RS256"}
    end

    test "rotate_keys/2 posts to the rotate path" do
      stub_json(201, %{"kid" => "def"})

      assert {:ok, %{"kid" => "def"}} = Connection.rotate_keys("con_123")

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/connections/con_123/keys/rotate"
    end
  end

  describe "status/1" do
    test "an online connection answers 200" do
      stub_request(%{})

      assert {:ok, %{}} = Connection.status("con_123")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/connections/con_123/status"
    end

    # Auth0 reports "offline" as a 404, so it arrives as an error like any other 404.
    # Documented on the function rather than translated into a boolean.
    test "an offline connection surfaces as a 404 error" do
      stub_json(404, %{"error" => "Not Found"})

      assert {:error, %Auth0Client.Error{status: 404}} = Connection.status("con_123")
    end
  end
end
