defmodule Auth0Client.Management.CustomDomainTest do
  use ExUnit.Case, async: true
  use Auth0Client.ReqCase

  alias Auth0Client.Management.CustomDomain

  @id "cd_abc123"

  describe "all/1" do
    test "gets all custom domains" do
      stub_request([%{"custom_domain_id" => @id, "domain" => "auth.example.com"}])

      assert {:ok, [%{"custom_domain_id" => @id}]} = CustomDomain.all()

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/custom-domains"
      assert request.query_string == ""
    end

    test "supports checkpoint pagination" do
      stub_request([])
      CustomDomain.all(take: 10, from: "cursor")

      assert assert_receive_request().query == %{"take" => "10", "from" => "cursor"}
    end
  end

  describe "get/1" do
    test "gets one by id" do
      stub_request(%{"custom_domain_id" => @id})

      assert {:ok, %{"custom_domain_id" => @id}} = CustomDomain.get(@id)

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/custom-domains/#{@id}"
    end
  end

  describe "create/1" do
    test "posts the domain and type" do
      stub_request(%{"custom_domain_id" => @id, "status" => "pending_verification"})

      assert {:ok, %{"status" => "pending_verification"}} =
               CustomDomain.create(%{domain: "auth.example.com", type: "auth0_managed_certs"})

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/custom-domains"

      assert request.body == %{
               "domain" => "auth.example.com",
               "type" => "auth0_managed_certs"
             }
    end

    # Auth0 is the only validator; the library passes type through untouched.
    test "sends type as given" do
      stub_request(%{})
      CustomDomain.create(%{domain: "auth.example.com", type: "self_managed_certs"})

      assert assert_receive_request().body["type"] == "self_managed_certs"
    end
  end

  describe "update/2" do
    test "patches the mutable fields" do
      stub_request(%{"custom_domain_id" => @id})

      assert {:ok, _} = CustomDomain.update(@id, %{tls_policy: "recommended"})

      request = assert_receive_request()
      assert request.method == "PATCH"
      assert request.path == "/api/v2/custom-domains/#{@id}"
      assert request.body == %{"tls_policy" => "recommended"}
    end
  end

  describe "delete/1" do
    test "deletes the domain" do
      stub_status(204)

      assert :ok = CustomDomain.delete(@id)

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/custom-domains/#{@id}"
    end
  end

  describe "verify/1 and test/1" do
    test "verify/1 posts to the verify path" do
      stub_request(%{"status" => "ready"})

      assert {:ok, %{"status" => "ready"}} = CustomDomain.verify(@id)

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/custom-domains/#{@id}/verify"
    end

    test "test/1 posts to the test path" do
      stub_request(%{})

      assert {:ok, _} = CustomDomain.test(@id)

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/custom-domains/#{@id}/test"
    end
  end

  describe "default/0 and set_default/1" do
    test "default/0 reads the current default" do
      stub_request(%{"domain" => "auth.example.com"})

      assert {:ok, %{"domain" => "auth.example.com"}} = CustomDomain.default()

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/custom-domains/default"
    end

    # Every other function here takes an id; this one takes the domain name, in
    # the body. That asymmetry is Auth0's.
    test "set_default/1 sends the domain name in the body, not an id in the path" do
      stub_request(%{"domain" => "auth.example.com"})

      assert {:ok, _} = CustomDomain.set_default("auth.example.com")

      request = assert_receive_request()
      assert request.method == "PATCH"
      assert request.path == "/api/v2/custom-domains/default"
      assert request.body == %{"domain" => "auth.example.com"}
      refute request.path =~ "auth.example.com"
    end
  end

  describe "authorization" do
    test "sends the management token" do
      stub_request([])
      CustomDomain.all()

      assert {"authorization", "Bearer TESTTOKEN"} in assert_receive_request().headers
    end
  end
end
