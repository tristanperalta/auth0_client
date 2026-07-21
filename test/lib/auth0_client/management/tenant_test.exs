defmodule Auth0Client.Management.TenantTest do
  use ExUnit.Case, async: true
  use Auth0Client.ReqCase

  alias Auth0Client.Management.Tenant

  describe "settings/1" do
    test "gets the tenant settings" do
      stub_request(%{"friendly_name" => "Acme", "support_email" => "help@example.com"})

      assert {:ok, %{"friendly_name" => "Acme"}} = Tenant.settings()

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/tenants/settings"
      assert request.query_string == ""
    end

    test "narrows the response with fields" do
      stub_request(%{"friendly_name" => "Acme"})

      Tenant.settings(fields: "friendly_name", include_fields: true)

      assert assert_receive_request().query == %{
               "fields" => "friendly_name",
               "include_fields" => "true"
             }
    end
  end

  describe "update_settings/1" do
    test "patches the settings" do
      stub_request(%{"friendly_name" => "Acme"})

      assert {:ok, %{"friendly_name" => "Acme"}} =
               Tenant.update_settings(%{friendly_name: "Acme"})

      request = assert_receive_request()
      assert request.method == "PATCH"
      assert request.path == "/api/v2/tenants/settings"
      assert request.body == %{"friendly_name" => "Acme"}
    end

    test "sends only the keys given, leaving the rest alone" do
      stub_request(%{})

      Tenant.update_settings(%{support_email: "help@example.com"})

      assert assert_receive_request().body == %{"support_email" => "help@example.com"}
    end

    test "carries nested settings through" do
      stub_request(%{})

      Tenant.update_settings(%{flags: %{enable_client_connections: false}})

      assert assert_receive_request().body == %{
               "flags" => %{"enable_client_connections" => false}
             }
    end
  end

  describe "authorization" do
    test "sends the management token" do
      stub_request(%{})
      Tenant.settings()

      assert {"authorization", "Bearer TESTTOKEN"} in assert_receive_request().headers
    end
  end
end
