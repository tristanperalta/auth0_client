defmodule Auth0Ex.Management.UserTest do
  use ExUnit.Case, async: true
  use Auth0Ex.ReqCase

  alias Auth0Ex.Management.User

  describe "all/0,1" do
    test "gets all users" do
      stub_request([%{"user_id" => "auth0|1"}])

      assert {:ok, [%{"user_id" => "auth0|1"}]} = User.all(%{fields: "name"})

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/users"
      assert request.query == %{"fields" => "name", "search_engine" => "v3"}
    end

    test "accepts a keyword list of params" do
      stub_request([])

      assert {:ok, []} = User.all(q: "app_metadata.admin:'true'", page: 2)

      assert assert_receive_request().query == %{
               "q" => "app_metadata.admin:'true'",
               "page" => "2",
               "search_engine" => "v3"
             }
    end

    test "sends the default search engine when called without params" do
      stub_request([])

      assert {:ok, []} = User.all()

      assert assert_receive_request().query_string == "search_engine=v3"
    end

    test "params override the default search engine" do
      stub_request([])

      assert {:ok, []} = User.all(%{search_engine: "v2"})

      assert assert_receive_request().query == %{"search_engine" => "v2"}
    end
  end

  describe "get/1,2" do
    test "gets a single user" do
      stub_request(%{"user_id" => "auth0|123"})

      assert {:ok, %{"user_id" => "auth0|123"}} = User.get("auth0|123")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/users/auth0|123"
      assert request.query == %{"search_engine" => "v3"}
    end

    test "passes through params" do
      stub_request(%{"user_id" => "auth0|123"})

      assert {:ok, _} = User.get("auth0|123", %{fields: "email,name,username"})

      assert assert_receive_request().query == %{
               "fields" => "email,name,username",
               "search_engine" => "v3"
             }
    end
  end

  describe "create/1,2" do
    test "posts the body with the connection merged in" do
      stub_request(%{"user_id" => "auth0|new"})

      assert {:ok, %{"user_id" => "auth0|new"}} =
               User.create("test_connection", %{
                 email: "test.user@email.com",
                 username: "test_user_name"
               })

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/users"

      assert request.body == %{
               "connection" => "test_connection",
               "email" => "test.user@email.com",
               "username" => "test_user_name"
             }
    end

    test "defaults to a body containing only the connection" do
      stub_request(%{"user_id" => "auth0|new"})

      assert {:ok, _} = User.create("test_connection")

      assert assert_receive_request().body == %{"connection" => "test_connection"}
    end
  end

  describe "update/1,2" do
    test "patches the body" do
      stub_request(%{"user_id" => "auth0|123"})

      assert {:ok, _} = User.update("auth0|123", %{app_metadata: %{admin: false}})

      request = assert_receive_request()
      assert request.method == "PATCH"
      assert request.path == "/api/v2/users/auth0|123"
      assert request.body == %{"app_metadata" => %{"admin" => false}}
    end

    test "defaults to an empty body" do
      stub_request(%{"user_id" => "auth0|123"})

      assert {:ok, _} = User.update("auth0|123")

      assert assert_receive_request().body == %{}
    end
  end

  describe "delete/1" do
    test "deletes and returns :ok on 204" do
      stub_request(fn conn -> Plug.Conn.send_resp(conn, 204, "") end)

      assert :ok = User.delete("auth0|123")

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/users/auth0|123"
      assert request.body == ""
    end
  end

  describe "log/2" do
    test "gets a user's logs" do
      stub_request([%{"type" => "s"}])

      assert {:ok, [%{"type" => "s"}]} = User.log("auth0|233423", %{})

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/users/auth0|233423/logs"
      assert request.query == %{"search_engine" => "v3"}
    end

    test "accepts a keyword list of params" do
      stub_request([])

      assert {:ok, []} = User.log("auth0|23423", page: 2, per_page: 10)

      assert assert_receive_request().query == %{
               "page" => "2",
               "per_page" => "10",
               "search_engine" => "v3"
             }
    end
  end

  describe "enrollments/1" do
    test "gets the guardian enrollments" do
      stub_request([%{"id" => "dev_1"}])

      assert {:ok, [%{"id" => "dev_1"}]} = User.enrollments("auth0|234")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/users/auth0|234/enrollments"
      assert request.query == %{"search_engine" => "v3"}
    end
  end

  describe "delete_mfprovider/2" do
    test "deletes the multifactor provider" do
      stub_request(fn conn -> Plug.Conn.send_resp(conn, 204, "") end)

      assert :ok = User.delete_mfprovider("auth0|23423", "duo")

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/users/auth0|23423/multifactor/duo"
    end
  end

  describe "unlink/3" do
    test "deletes the secondary identity" do
      stub_request([%{"provider" => "auth0"}])

      assert {:ok, [%{"provider" => "auth0"}]} =
               User.unlink("some_user_id", "github", "23984234")

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/users/some_user_id/identities/github/23984234"
    end
  end

  describe "regenerate_recovery_code/1" do
    test "posts to the recovery-code-regeneration path" do
      stub_request(%{"recovery_code" => "ABC123"})

      assert {:ok, %{"recovery_code" => "ABC123"}} = User.regenerate_recovery_code("auth0|34234")

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/users/auth0|34234/recovery-code-regeneration"
      assert request.body == %{}
    end
  end

  describe "link/2" do
    test "posts the link body" do
      stub_request([%{"provider" => "github"}])

      assert {:ok, [%{"provider" => "github"}]} =
               User.link("some_user_id", %{link_with: "secondary_acc_jwt"})

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/users/some_user_id/identities"
      assert request.body == %{"link_with" => "secondary_acc_jwt"}
    end

    test "accepts a keyword list body" do
      stub_request([])

      assert {:ok, []} =
               User.link("some_user_id",
                 provider: "github",
                 user_id: "23423",
                 connection_id: "som"
               )

      assert assert_receive_request().body == %{
               "provider" => "github",
               "user_id" => "23423",
               "connection_id" => "som"
             }
    end
  end

  describe "roles/1,2" do
    test "gets the roles for a user" do
      stub_request([%{"id" => "rol_1"}])

      assert {:ok, [%{"id" => "rol_1"}]} = User.roles("auth0|23423")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/users/auth0|23423/roles"
      assert request.query == %{"search_engine" => "v3"}
    end

    test "passes through params" do
      stub_request([])

      assert {:ok, []} = User.roles("auth0|23423", %{per_page: 5})

      assert assert_receive_request().query == %{
               "per_page" => "5",
               "search_engine" => "v3"
             }
    end
  end

  describe "delete_authentication_methods/1" do
    test "deletes all authentication methods" do
      stub_request(fn conn -> Plug.Conn.send_resp(conn, 204, "") end)

      assert :ok = User.delete_authentication_methods("auth0|23423")

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/users/auth0|23423/authentication-methods"
    end
  end

  describe "authorization" do
    test "sends the configured management token" do
      stub_request([])

      assert {:ok, []} = User.all()

      headers = assert_receive_request().headers
      assert {"authorization", "Bearer TESTTOKEN"} in headers
    end
  end
end
