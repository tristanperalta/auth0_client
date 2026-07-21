defmodule Auth0Ex.Management.ClientGrantTest do
  use ExUnit.Case, async: true
  use Auth0Ex.ReqCase

  alias Auth0Ex.Management.ClientGrant

  describe "all/0,1" do
    test "gets all client grants" do
      stub_request([%{"id" => "cgr_123"}])

      assert {:ok, [%{"id" => "cgr_123"}]} = ClientGrant.all(%{audience: "aud"})

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/client-grants"
      assert request.query == %{"audience" => "aud"}
    end

    test "accepts a keyword list of params" do
      stub_request([])

      assert {:ok, []} = ClientGrant.all(audience: "aud", client_id: "abc123")

      assert assert_receive_request().query == %{
               "audience" => "aud",
               "client_id" => "abc123"
             }
    end

    test "sends no params by default" do
      stub_request([])

      assert {:ok, []} = ClientGrant.all()

      request = assert_receive_request()
      assert request.path == "/api/v2/client-grants"
      assert request.query_string == ""
    end
  end

  describe "get/1" do
    test "gets a single client grant" do
      stub_request(%{"id" => "cgr_1", "audience" => "https://api.example.com"})

      assert {:ok, %{"id" => "cgr_1"}} = ClientGrant.get("cgr_1")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/client-grants/cgr_1"
    end
  end

  describe "organizations/2" do
    test "lists the organizations for a grant" do
      stub_request([%{"id" => "org_1"}])

      assert {:ok, [%{"id" => "org_1"}]} = ClientGrant.organizations("cgr_1")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/client-grants/cgr_1/organizations"
    end

    test "supports checkpoint pagination" do
      stub_request([])
      ClientGrant.organizations("cgr_1", take: 50)

      assert assert_receive_request().query == %{"take" => "50"}
    end
  end

  describe "create/1" do
    test "posts the body" do
      stub_request(%{"id" => "cgr_123"})

      assert {:ok, %{"id" => "cgr_123"}} =
               ClientGrant.create(%{client_id: "abc123", audience: "someaud", scope: []})

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/client-grants"

      assert request.body == %{
               "client_id" => "abc123",
               "audience" => "someaud",
               "scope" => []
             }
    end

    test "accepts a keyword list body" do
      stub_request(%{"id" => "cgr_123"})

      assert {:ok, _} = ClientGrant.create(client_id: "abc123", audience: "someaud")

      assert assert_receive_request().body == %{
               "client_id" => "abc123",
               "audience" => "someaud"
             }
    end
  end

  describe "update/2" do
    test "patches the body" do
      stub_request(%{"id" => "cgr_123"})

      assert {:ok, _} = ClientGrant.update("cgr_123", %{scope: ["read:foo"]})

      request = assert_receive_request()
      assert request.method == "PATCH"
      assert request.path == "/api/v2/client-grants/cgr_123"
      assert request.body == %{"scope" => ["read:foo"]}
    end

    test "accepts a keyword list body" do
      stub_request(%{"id" => "cgr_123"})

      assert {:ok, _} = ClientGrant.update("cgr_123", scope: [])

      assert assert_receive_request().body == %{"scope" => []}
    end
  end

  describe "delete/1" do
    test "deletes and returns :ok on 204" do
      stub_request(fn conn -> Plug.Conn.send_resp(conn, 204, "") end)

      assert :ok = ClientGrant.delete("cgr_123")

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/client-grants/cgr_123"
      assert request.query_string == ""
    end
  end
end
