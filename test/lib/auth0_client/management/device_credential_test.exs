defmodule Auth0Client.Management.DeviceCredentialTest do
  use ExUnit.Case, async: true
  use Auth0Client.ReqCase

  alias Auth0Client.Management.DeviceCredential

  describe "all/0,1" do
    test "gets all device credentials" do
      stub_request([%{"device_name" => "adev"}])

      assert {:ok, [%{"device_name" => "adev"}]} = DeviceCredential.all(%{fields: "id"})

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/device-credentials"
      assert request.query == %{"fields" => "id"}
    end

    test "accepts a keyword list of params" do
      stub_request([])

      assert {:ok, []} = DeviceCredential.all(fields: "id,device_name")

      assert assert_receive_request().query == %{"fields" => "id,device_name"}
    end

    test "sends no params by default" do
      stub_request([])

      assert {:ok, []} = DeviceCredential.all()

      request = assert_receive_request()
      assert request.path == "/api/v2/device-credentials"
      assert request.query_string == ""
    end
  end

  describe "create/1" do
    test "posts the body" do
      stub_request(%{"id" => "dcred_1"})

      assert {:ok, %{"id" => "dcred_1"}} = DeviceCredential.create(%{device_name: "adev"})

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/device-credentials"
      assert request.body == %{"device_name" => "adev"}
    end

    test "accepts a keyword list body" do
      stub_request(%{"id" => "dcred_1"})

      assert {:ok, _} = DeviceCredential.create(device_name: "adev")

      assert assert_receive_request().body == %{"device_name" => "adev"}
    end
  end

  describe "delete/1" do
    test "deletes and returns :ok on 204" do
      stub_status(204)

      assert :ok = DeviceCredential.delete("dcred_1")

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/device-credentials/dcred_1"
    end
  end

  describe "authorization" do
    test "sends the configured management token" do
      stub_request([])

      assert {:ok, []} = DeviceCredential.all()

      assert {"authorization", "Bearer TESTTOKEN"} in assert_receive_request().headers
    end
  end
end
