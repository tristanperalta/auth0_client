defmodule Auth0Client.Management.EmailProviderTest do
  use ExUnit.Case, async: true
  use Auth0Client.ReqCase

  alias Auth0Client.Management.EmailProvider

  describe "get/0,1" do
    test "gets the email provider" do
      stub_request(%{"name" => "mandrill"})

      assert {:ok, %{"name" => "mandrill"}} = EmailProvider.get()

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/emails/provider"
      assert request.query_string == ""
    end

    test "passes through a keyword list of params" do
      stub_request(%{"name" => "mandrill"})

      assert {:ok, _} = EmailProvider.get(fields: "name,enabled")

      assert assert_receive_request().query == %{"fields" => "name,enabled"}
    end

    test "passes through a map of params" do
      stub_request(%{"name" => "mandrill"})

      assert {:ok, _} = EmailProvider.get(%{fields: "name", include_fields: true})

      assert assert_receive_request().query == %{
               "fields" => "name",
               "include_fields" => "true"
             }
    end
  end

  describe "configure/1" do
    test "posts the body" do
      stub_request(%{"name" => "mandrill"})

      assert {:ok, %{"name" => "mandrill"}} =
               EmailProvider.configure(%{name: "mandrill", enabled: true})

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/emails/provider"
      assert request.body == %{"name" => "mandrill", "enabled" => true}
    end

    test "accepts a keyword list body" do
      stub_request(%{"name" => "mandrill"})

      assert {:ok, _} = EmailProvider.configure(name: "mandrill", enabled: true)

      assert assert_receive_request().body == %{"name" => "mandrill", "enabled" => true}
    end
  end

  describe "update/1" do
    test "patches the body" do
      stub_request(%{"name" => "new_name"})

      assert {:ok, _} = EmailProvider.update(%{name: "new_name"})

      request = assert_receive_request()
      assert request.method == "PATCH"
      assert request.path == "/api/v2/emails/provider"
      assert request.body == %{"name" => "new_name"}
    end

    test "accepts a keyword list body" do
      stub_request(%{"name" => "new_name"})

      assert {:ok, _} = EmailProvider.update(name: "new_name")

      assert assert_receive_request().body == %{"name" => "new_name"}
    end
  end

  describe "delete/0" do
    test "deletes and returns :ok on 204" do
      stub_status(204)

      assert :ok = EmailProvider.delete()

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/emails/provider"
    end
  end

  describe "authorization" do
    test "sends the configured management token" do
      stub_request(%{})

      assert {:ok, _} = EmailProvider.get()

      assert {"authorization", "Bearer TESTTOKEN"} in assert_receive_request().headers
    end
  end
end
