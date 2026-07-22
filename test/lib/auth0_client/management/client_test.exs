defmodule Auth0Client.Management.ClientTest do
  use ExUnit.Case, async: true
  use Auth0Client.ReqCase

  alias Auth0Client.Management.Client

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
      stub_status(204)

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

  describe "connections/2" do
    test "lists the client's connections" do
      stub_request([%{"id" => "con_1"}])

      assert {:ok, [%{"id" => "con_1"}]} = Client.connections("abc123")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/clients/abc123/connections"
    end

    test "filters by strategy and paginates" do
      stub_request([])
      Client.connections("abc123", strategy: "auth0", take: 25)

      assert assert_receive_request().query == %{"strategy" => "auth0", "take" => "25"}
    end
  end

  describe "credentials" do
    test "credentials/1 lists them" do
      stub_request([%{"id" => "cred_1", "credential_type" => "public_key"}])

      assert {:ok, [%{"id" => "cred_1"}]} = Client.credentials("abc123")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/clients/abc123/credentials"
    end

    test "credential/2 gets one" do
      stub_request(%{"id" => "cred_1"})

      assert {:ok, %{"id" => "cred_1"}} = Client.credential("abc123", "cred_1")

      assert assert_receive_request().path == "/api/v2/clients/abc123/credentials/cred_1"
    end

    test "create_credential/2 posts the credential" do
      stub_json(201, %{"id" => "cred_1"})

      assert {:ok, %{"id" => "cred_1"}} =
               Client.create_credential("abc123", %{
                 credential_type: "public_key",
                 pem: "-----BEGIN PUBLIC KEY-----",
                 alg: "RS256"
               })

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/clients/abc123/credentials"
      assert request.body["credential_type"] == "public_key"
      assert request.body["alg"] == "RS256"
    end

    # Auth0 answers this PATCH with 201 rather than 200.
    test "update_credential/3 patches expires_at and accepts a 201" do
      stub_json(201, %{"id" => "cred_1"})

      assert {:ok, %{"id" => "cred_1"}} =
               Client.update_credential("abc123", "cred_1", %{expires_at: "2027-01-01T00:00:00Z"})

      request = assert_receive_request()
      assert request.method == "PATCH"
      assert request.path == "/api/v2/clients/abc123/credentials/cred_1"
      assert request.body == %{"expires_at" => "2027-01-01T00:00:00Z"}
    end

    test "delete_credential/2 removes one" do
      stub_status(204)

      assert :ok = Client.delete_credential("abc123", "cred_1")

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/clients/abc123/credentials/cred_1"
    end

    test "credentials and connections build distinct paths under the same id" do
      stub_request([])
      Client.credentials("abc123")
      credentials = assert_receive_request().path

      stub_request([])
      Client.connections("abc123")
      connections = assert_receive_request().path

      assert credentials == "/api/v2/clients/abc123/credentials"
      assert connections == "/api/v2/clients/abc123/connections"
    end
  end

  describe "client id metadata documents" do
    test "preview_metadata_document/1 validates without creating" do
      stub_request(%{"metadata" => %{}})

      assert {:ok, _} =
               Client.preview_metadata_document(%{
                 external_client_id: "https://app.example.com/metadata"
               })

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/clients/cimd/preview"
      assert request.body == %{"external_client_id" => "https://app.example.com/metadata"}
    end

    # Upsert: 201 when Auth0 creates the application, 200 when it updates one.
    test "register_metadata_document/1 accepts a 201 for a new client" do
      stub_json(201, %{"client_id" => "new"})

      assert {:ok, %{"client_id" => "new"}} =
               Client.register_metadata_document(%{external_client_id: "https://app/metadata"})

      assert assert_receive_request().path == "/api/v2/clients/cimd/register"
    end

    test "register_metadata_document/1 accepts a 200 for an existing client" do
      stub_request(%{"client_id" => "existing"})

      assert {:ok, %{"client_id" => "existing"}} =
               Client.register_metadata_document(%{external_client_id: "https://app/metadata"})
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
