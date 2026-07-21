defmodule Auth0Ex.Management.ResourceServerTest do
  use ExUnit.Case, async: true
  use Auth0Ex.ReqCase

  alias Auth0Ex.Management.ResourceServer

  describe "all/0" do
    test "gets all resource servers" do
      stub_request([%{"identifier" => "https://api.example.com"}])

      assert {:ok, [%{"identifier" => "https://api.example.com"}]} = ResourceServer.all()

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/resource-servers"
      assert request.query_string == ""
    end
  end

  describe "get/1" do
    test "gets a single resource server" do
      stub_request(%{"id" => "resserver"})

      assert {:ok, %{"id" => "resserver"}} = ResourceServer.get("resserver")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/resource-servers/resserver"
      assert request.query_string == ""
    end
  end

  describe "create/1" do
    test "posts the body" do
      stub_request(%{"name" => "resserver"})

      assert {:ok, %{"name" => "resserver"}} =
               ResourceServer.create(%{name: "resserver", identifier: "https://api.example.com"})

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/resource-servers"

      assert request.body == %{
               "name" => "resserver",
               "identifier" => "https://api.example.com"
             }
    end

    test "accepts a keyword list body" do
      stub_request(%{"name" => "resserver"})

      assert {:ok, _} = ResourceServer.create(name: "resserver")

      assert assert_receive_request().body == %{"name" => "resserver"}
    end
  end

  describe "update/2" do
    test "patches the body" do
      stub_request(%{"name" => "renamed"})

      assert {:ok, _} = ResourceServer.update("resserver", %{name: "renamed"})

      request = assert_receive_request()
      assert request.method == "PATCH"
      assert request.path == "/api/v2/resource-servers/resserver"
      assert request.body == %{"name" => "renamed"}
    end

    test "accepts a keyword list body" do
      stub_request(%{"name" => "renamed"})

      assert {:ok, _} = ResourceServer.update("resserver", name: "renamed")

      assert assert_receive_request().body == %{"name" => "renamed"}
    end
  end

  describe "delete/1" do
    test "deletes and returns :ok on 204" do
      stub_request(fn conn -> Plug.Conn.send_resp(conn, 204, "") end)

      assert :ok = ResourceServer.delete("resserver")

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/resource-servers/resserver"
      assert request.query_string == ""
    end
  end
end
