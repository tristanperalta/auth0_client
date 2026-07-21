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

  describe "by_email/1,2" do
    # A different top-level path from every other function in this module.
    test "hits /users-by-email, not /users" do
      stub_request([%{"user_id" => "auth0|123", "email" => "someone@example.com"}])

      assert {:ok, [%{"email" => "someone@example.com"}]} =
               User.by_email("someone@example.com")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/users-by-email"
      refute request.path =~ "/users/"
    end

    test "always sends the email as a query param" do
      stub_request([])
      User.by_email("someone@example.com")

      assert assert_receive_request().query == %{"email" => "someone@example.com"}
    end

    test "passes through field filtering alongside the email" do
      stub_request([])
      User.by_email("someone@example.com", fields: "user_id,email")

      assert assert_receive_request().query == %{
               "email" => "someone@example.com",
               "fields" => "user_id,email"
             }
    end

    test "sends no search_engine, unlike all/1" do
      stub_request([])
      User.by_email("someone@example.com")

      refute Map.has_key?(assert_receive_request().query, "search_engine")
    end
  end

  describe "get/1,2" do
    test "gets a single user" do
      stub_request(%{"user_id" => "auth0|123"})

      assert {:ok, %{"user_id" => "auth0|123"}} = User.get("auth0|123")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/users/auth0|123"
      assert request.query == %{}
    end

    test "passes through params" do
      stub_request(%{"user_id" => "auth0|123"})

      assert {:ok, _} = User.get("auth0|123", %{fields: "email,name,username"})

      assert assert_receive_request().query == %{"fields" => "email,name,username"}
    end

    test "accepts a keyword list, like all/1" do
      stub_request(%{"user_id" => "auth0|123"})

      assert {:ok, _} = User.get("auth0|123", fields: "email")

      assert assert_receive_request().query == %{"fields" => "email"}
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
      assert request.query == %{}
    end

    test "accepts a keyword list of params" do
      stub_request([])

      assert {:ok, []} = User.log("auth0|23423", page: 2, per_page: 10)

      assert assert_receive_request().query == %{"page" => "2", "per_page" => "10"}
    end
  end

  describe "enrollments/1" do
    test "gets the guardian enrollments" do
      stub_request([%{"id" => "dev_1"}])

      assert {:ok, [%{"id" => "dev_1"}]} = User.enrollments("auth0|234")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/users/auth0|234/enrollments"
      assert request.query == %{}
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
      assert request.query == %{}
    end

    test "passes through params" do
      stub_request([])

      assert {:ok, []} = User.roles("auth0|23423", %{per_page: 5})

      assert assert_receive_request().query == %{"per_page" => "5"}
    end
  end

  describe "assign_roles/2" do
    test "posts the role ids" do
      stub_request(fn conn -> Plug.Conn.send_resp(conn, 204, "") end)

      assert :ok = User.assign_roles("auth0|123", ["rol_1", "rol_2"])

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/users/auth0|123/roles"
      assert request.body == %{"roles" => ["rol_1", "rol_2"]}
    end
  end

  describe "remove_roles/2" do
    test "sends the role ids in the body of a DELETE" do
      stub_request(fn conn -> Plug.Conn.send_resp(conn, 204, "") end)

      assert :ok = User.remove_roles("auth0|123", ["rol_1"])

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/users/auth0|123/roles"
      assert request.body == %{"roles" => ["rol_1"]}
    end
  end

  describe "permissions/2" do
    test "gets the user's direct permissions" do
      stub_request([%{"permission_name" => "read:users"}])

      assert {:ok, [%{"permission_name" => "read:users"}]} = User.permissions("auth0|123")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/users/auth0|123/permissions"
    end
  end

  describe "assign_permissions/2" do
    test "posts permissions given as tuples" do
      stub_request(fn conn -> Plug.Conn.send_resp(conn, 201, "") end)

      assert :ok =
               User.assign_permissions("auth0|123", [{"https://api.example.com", "read:users"}])

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/users/auth0|123/permissions"

      assert request.body == %{
               "permissions" => [
                 %{
                   "resource_server_identifier" => "https://api.example.com",
                   "permission_name" => "read:users"
                 }
               ]
             }
    end

    test "the map form sends the same body as the tuple shorthand" do
      stub_request(fn conn -> Plug.Conn.send_resp(conn, 201, "") end)
      User.assign_permissions("auth0|123", [{"https://api.example.com", "read:users"}])
      from_tuple = assert_receive_request().body

      stub_request(fn conn -> Plug.Conn.send_resp(conn, 201, "") end)

      User.assign_permissions("auth0|123", [
        %{resource_server_identifier: "https://api.example.com", permission_name: "read:users"}
      ])

      assert assert_receive_request().body == from_tuple
    end
  end

  describe "remove_permissions/2" do
    test "sends the permissions in the body of a DELETE" do
      stub_request(fn conn -> Plug.Conn.send_resp(conn, 204, "") end)

      assert :ok =
               User.remove_permissions("auth0|123", [{"https://api.example.com", "read:users"}])

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/users/auth0|123/permissions"
      assert %{"permissions" => [_]} = request.body
    end
  end

  describe "organizations/2" do
    test "lists the user's organizations" do
      stub_request([%{"id" => "org_1"}])

      assert {:ok, [%{"id" => "org_1"}]} = User.organizations("auth0|123")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/users/auth0|123/organizations"
    end
  end

  describe "effective roles and permissions" do
    test "effective_roles/2 includes roles inherited through groups" do
      stub_request([%{"id" => "rol_1"}])

      assert {:ok, [%{"id" => "rol_1"}]} = User.effective_roles("auth0|123")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/users/auth0|123/effective-roles"
    end

    test "effective_roles/2 supports checkpoint pagination" do
      stub_request([])
      User.effective_roles("auth0|123", take: 25)

      assert assert_receive_request().query == %{"take" => "25"}
    end

    test "effective_role_source_groups/2 explains where a role comes from" do
      stub_request([])
      User.effective_role_source_groups("auth0|123", role_id: "rol_1")

      request = assert_receive_request()
      assert request.path == "/api/v2/users/auth0|123/effective-roles/sources/groups"
      assert request.query == %{"role_id" => "rol_1"}
    end

    test "effective_permissions/2 can be scoped to one api" do
      stub_request([])

      User.effective_permissions("auth0|123",
        resource_server_identifier: "https://api.example.com"
      )

      request = assert_receive_request()
      assert request.path == "/api/v2/users/auth0|123/effective-permissions"
      assert request.query == %{"resource_server_identifier" => "https://api.example.com"}
    end

    test "effective_permission_source_roles/2 explains where a permission comes from" do
      stub_request([])

      User.effective_permission_source_roles("auth0|123",
        resource_server_identifier: "https://api.example.com",
        permission_name: "read:users"
      )

      request = assert_receive_request()

      assert request.path ==
               "/api/v2/users/auth0|123/effective-permissions/sources/effective-roles"

      assert request.query == %{
               "resource_server_identifier" => "https://api.example.com",
               "permission_name" => "read:users"
             }
    end
  end

  describe "authentication methods" do
    test "authentication_methods/2 lists them" do
      stub_request([%{"id" => "aum_1", "type" => "totp"}])

      assert {:ok, [%{"id" => "aum_1"}]} = User.authentication_methods("auth0|123")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/users/auth0|123/authentication-methods"
    end

    test "authentication_method/2 gets one" do
      stub_request(%{"id" => "aum_1"})

      assert {:ok, %{"id" => "aum_1"}} = User.authentication_method("auth0|123", "aum_1")

      assert assert_receive_request().path ==
               "/api/v2/users/auth0|123/authentication-methods/aum_1"
    end

    test "create_authentication_method/2 posts the method" do
      stub_request(%{"id" => "aum_1"})

      assert {:ok, _} =
               User.create_authentication_method("auth0|123", %{type: "email", email: "a@b.com"})

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/users/auth0|123/authentication-methods"
      assert request.body == %{"type" => "email", "email" => "a@b.com"}
    end

    test "update_authentication_method/3 patches it" do
      stub_request(%{"id" => "aum_1"})

      assert {:ok, _} =
               User.update_authentication_method("auth0|123", "aum_1", %{name: "Work phone"})

      request = assert_receive_request()
      assert request.method == "PATCH"
      assert request.path == "/api/v2/users/auth0|123/authentication-methods/aum_1"
      assert request.body == %{"name" => "Work phone"}
    end

    test "delete_authentication_method/2 deletes one" do
      stub_request(fn conn -> Plug.Conn.send_resp(conn, 204, "") end)

      assert :ok = User.delete_authentication_method("auth0|123", "aum_1")

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/users/auth0|123/authentication-methods/aum_1"
    end

    # The body here is a bare array, not an object wrapping one.
    test "replace_authentication_methods/2 puts a bare list" do
      stub_request([%{"id" => "aum_1"}])

      assert {:ok, _} =
               User.replace_authentication_methods("auth0|123", [
                 %{type: "email", email: "a@b.com"}
               ])

      request = assert_receive_request()
      assert request.method == "PUT"
      assert request.path == "/api/v2/users/auth0|123/authentication-methods"
      assert request.body == [%{"type" => "email", "email" => "a@b.com"}]
      assert is_list(request.body)
    end
  end

  describe "MFA reset" do
    test "delete_authenticators/1 clears every authenticator" do
      stub_request(fn conn -> Plug.Conn.send_resp(conn, 204, "") end)

      assert :ok = User.delete_authenticators("auth0|123")

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/users/auth0|123/authenticators"
    end

    test "invalidate_remember_browser/1 forces the next login to prompt" do
      stub_request(fn conn -> Plug.Conn.send_resp(conn, 204, "") end)

      assert :ok = User.invalidate_remember_browser("auth0|123")

      request = assert_receive_request()
      assert request.method == "POST"

      assert request.path ==
               "/api/v2/users/auth0|123/multifactor/actions/invalidate-remember-browser"
    end
  end

  describe "sessions and refresh tokens" do
    test "sessions/2 lists them with checkpoint pagination" do
      stub_request(%{"sessions" => []})

      assert {:ok, %{"sessions" => []}} = User.sessions("auth0|123", take: 10)

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/users/auth0|123/sessions"
      assert request.query == %{"take" => "10"}
    end

    # These answer 202, which only became a success case recently.
    test "delete_sessions/1 signs the user out everywhere" do
      stub_request(fn conn -> conn |> Plug.Conn.put_status(202) |> Req.Test.json(%{}) end)

      assert {:ok, _} = User.delete_sessions("auth0|123")

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/users/auth0|123/sessions"
    end

    test "refresh_tokens/2 lists them" do
      stub_request(%{"tokens" => []})

      assert {:ok, %{"tokens" => []}} = User.refresh_tokens("auth0|123", from: "cursor")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/users/auth0|123/refresh-tokens"
      assert request.query == %{"from" => "cursor"}
    end

    test "delete_refresh_tokens/1 revokes them" do
      stub_request(fn conn -> conn |> Plug.Conn.put_status(202) |> Req.Test.json(%{}) end)

      assert {:ok, _} = User.delete_refresh_tokens("auth0|123")

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/users/auth0|123/refresh-tokens"
    end

    test "revoke_access/2 revokes sessions and tokens together" do
      stub_request(fn conn -> conn |> Plug.Conn.put_status(202) |> Req.Test.json(%{}) end)

      assert {:ok, _} = User.revoke_access("auth0|123", %{preserve_refresh_tokens: true})

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/users/auth0|123/revoke-access"
      assert request.body == %{"preserve_refresh_tokens" => true}
    end

    test "revoke_access/1 defaults to an empty body" do
      stub_request(fn conn -> conn |> Plug.Conn.put_status(202) |> Req.Test.json(%{}) end)

      assert {:ok, _} = User.revoke_access("auth0|123")

      assert assert_receive_request().body == %{}
    end
  end

  describe "groups, connected accounts and risk assessments" do
    test "groups/2 lists the user's groups" do
      stub_request([%{"id" => "grp_1"}])

      assert {:ok, [%{"id" => "grp_1"}]} = User.groups("auth0|123")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/users/auth0|123/groups"
    end

    test "connected_accounts/2 lists them with checkpoint pagination" do
      stub_request(%{"connected_accounts" => []})

      assert {:ok, _} = User.connected_accounts("auth0|123", take: 5)

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/users/auth0|123/connected-accounts"
      assert request.query == %{"take" => "5"}
    end

    test "clear_risk_assessments/2 posts to the clear path" do
      stub_request(fn conn -> Plug.Conn.send_resp(conn, 204, "") end)

      assert :ok = User.clear_risk_assessments("auth0|123", %{assessors: ["NewDevice"]})

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/users/auth0|123/risk-assessments/clear"
      assert request.body == %{"assessors" => ["NewDevice"]}
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
