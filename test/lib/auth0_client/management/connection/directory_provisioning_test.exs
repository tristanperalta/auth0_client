defmodule Auth0Client.Management.Connection.DirectoryProvisioningTest do
  use ExUnit.Case, async: true
  use Auth0Client.ReqCase

  alias Auth0Client.Management.Connection.DirectoryProvisioning

  describe "all/1" do
    # The tenant-wide listing lives at its own top-level path, not under a connection.
    test "hits the tenant-level path" do
      stub_request(%{"directory_provisionings" => []})

      assert {:ok, %{"directory_provisionings" => []}} = DirectoryProvisioning.all()

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/connections-directory-provisionings"
      assert request.query_string == ""
    end

    test "supports checkpoint pagination" do
      stub_request(%{})
      DirectoryProvisioning.all(from: "abc", take: 50)

      assert assert_receive_request().query == %{"from" => "abc", "take" => "50"}
    end
  end

  describe "get/1" do
    # Distinct from Scim.get/1 and Connection.get/1 under the same connection id.
    test "gets the configuration for a connection" do
      stub_request(%{"connection_id" => "con_123"})

      assert {:ok, %{"connection_id" => "con_123"}} = DirectoryProvisioning.get("con_123")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/connections/con_123/directory-provisioning"
    end
  end

  describe "create/2" do
    test "posts the configuration and accepts a 201" do
      stub_json(201, %{"connection_id" => "con_123"})

      assert {:ok, %{"connection_id" => "con_123"}} =
               DirectoryProvisioning.create("con_123", %{
                 mapping: [%{auth0: "email", idp: "mail"}],
                 synchronize_automatically: true,
                 synchronize_groups: "all"
               })

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/connections/con_123/directory-provisioning"

      assert request.body == %{
               "mapping" => [%{"auth0" => "email", "idp" => "mail"}],
               "synchronize_automatically" => true,
               "synchronize_groups" => "all"
             }
    end
  end

  describe "update/2" do
    test "patches the configuration" do
      stub_request(%{"connection_id" => "con_123"})

      assert {:ok, _} =
               DirectoryProvisioning.update("con_123", %{synchronize_automatically: false})

      request = assert_receive_request()
      assert request.method == "PATCH"
      assert request.path == "/api/v2/connections/con_123/directory-provisioning"
      assert request.body == %{"synchronize_automatically" => false}
    end
  end

  describe "delete/1" do
    test "deletes and returns :ok on 204" do
      stub_status(204)

      assert :ok = DirectoryProvisioning.delete("con_123")

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/connections/con_123/directory-provisioning"
    end
  end

  describe "default_mapping/1" do
    test "gets the default mapping" do
      stub_request(%{"mapping" => []})

      assert {:ok, %{"mapping" => []}} = DirectoryProvisioning.default_mapping("con_123")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/connections/con_123/directory-provisioning/default-mapping"
    end
  end

  describe "synchronize/1" do
    test "posts to the synchronizations path and accepts a 201" do
      stub_status(201)

      assert :ok = DirectoryProvisioning.synchronize("con_123")

      request = assert_receive_request()
      assert request.method == "POST"

      assert request.path ==
               "/api/v2/connections/con_123/directory-provisioning/synchronizations"
    end
  end

  describe "synchronized groups" do
    test "synchronized_groups/2 lists them with checkpoint pagination" do
      stub_request(%{"groups" => []})

      assert {:ok, %{"groups" => []}} =
               DirectoryProvisioning.synchronized_groups("con_123", take: 50)

      request = assert_receive_request()
      assert request.method == "GET"

      assert request.path ==
               "/api/v2/connections/con_123/directory-provisioning/synchronized-groups"

      assert request.query == %{"take" => "50"}
    end

    test "replace_synchronized_groups/2 puts and returns :ok on 204" do
      stub_status(204)

      assert :ok =
               DirectoryProvisioning.replace_synchronized_groups("con_123", %{
                 groups: [%{id: "03x8tuzt3mkl0ub"}]
               })

      request = assert_receive_request()
      assert request.method == "PUT"

      assert request.path ==
               "/api/v2/connections/con_123/directory-provisioning/synchronized-groups"

      assert request.body == %{"groups" => [%{"id" => "03x8tuzt3mkl0ub"}]}
    end
  end
end
