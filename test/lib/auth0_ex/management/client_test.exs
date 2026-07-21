defmodule Auth0Ex.Management.ClientTest do
  use ExUnit.Case, async: true
  use Auth0Ex.ReqCase

  alias Auth0Ex.Management.Client

  describe "all/1" do
    test "gets all clients" do
      stub_request([%{"name" => "Some App"}])

      assert {:ok, [%{"name" => "Some App"}]} = Client.all(%{fields: "name"})

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/clients"
      assert request.query == %{"fields" => "name"}
    end

    test "accepts a keyword list of params" do
      stub_request([])

      assert {:ok, []} = Client.all(fields: "name,client_id")

      assert assert_receive_request().query == %{"fields" => "name,client_id"}
    end

    test "sends no params by default" do
      stub_request([])

      assert {:ok, []} = Client.all()

      assert assert_receive_request().query_string == ""
    end
  end

  describe "get/1,2" do
    test "gets a single client" do
      stub_request(%{"client_id" => "abc123"})

      assert {:ok, %{"client_id" => "abc123"}} = Client.get("abc123")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/clients/abc123"
    end

    test "passes through params" do
      stub_request(%{"client_id" => "abc123"})

      assert {:ok, _} = Client.get("abc123", fields: "client_id", include_fields: true)

      assert assert_receive_request().query == %{
               "fields" => "client_id",
               "include_fields" => "true"
             }
    end
  end

  describe "create/1" do
    test "posts the body" do
      stub_request(%{"name" => "Samars App"})

      assert {:ok, %{"name" => "Samars App"}} = Client.create(%{name: "Samars App"})

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/clients"
      assert request.body == %{"name" => "Samars App"}
    end
  end

  describe "update/2" do
    test "patches the body" do
      stub_request(%{"name" => "New Name"})

      assert {:ok, _} = Client.update("abc123", %{name: "New Name"})

      request = assert_receive_request()
      assert request.method == "PATCH"
      assert request.path == "/api/v2/clients/abc123"
      assert request.body == %{"name" => "New Name"}
    end
  end

  describe "delete/1" do
    test "deletes and returns :ok on 204" do
      stub_request(fn conn -> Plug.Conn.send_resp(conn, 204, "") end)

      assert :ok = Client.delete("abc123")

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/clients/abc123"
    end
  end

  describe "rotate_secret/1" do
    test "posts to the rotate-secret path" do
      stub_request(%{"client_secret" => "new_secret"})

      assert {:ok, %{"client_secret" => "new_secret"}} = Client.rotate_secret("abc123")

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/clients/abc123/rotate-secret"
    end
  end

  describe "authorization" do
    test "sends the configured management token" do
      stub_request([])

      assert {:ok, []} = Client.all()

      headers = assert_receive_request().headers
      assert {"authorization", "Bearer TESTTOKEN"} in headers
    end
  end
end
