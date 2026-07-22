defmodule Auth0Client.Management.RoleTest do
  use ExUnit.Case, async: true
  use Auth0Client.ReqCase

  alias Auth0Client.Management.Role

  @permission %{
    "resource_server_identifier" => "https://api.example.com",
    "permission_name" => "read:users"
  }

  describe "all/1" do
    test "gets all roles" do
      stub_request([%{"id" => "rol_1", "name" => "admin"}])

      assert {:ok, [%{"id" => "rol_1"}]} = Role.all()

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/roles"
      assert request.query_string == ""
    end

    test "passes through a name filter and pagination" do
      stub_request([])

      assert {:ok, []} = Role.all(name_filter: "admin", per_page: 50, include_totals: true)

      assert assert_receive_request().query == %{
               "name_filter" => "admin",
               "per_page" => "50",
               "include_totals" => "true"
             }
    end

    test "accepts a map of params" do
      stub_request([])
      Role.all(%{page: 2})

      assert assert_receive_request().query == %{"page" => "2"}
    end
  end

  describe "get/1" do
    test "gets a single role" do
      stub_request(%{"id" => "rol_1"})

      assert {:ok, %{"id" => "rol_1"}} = Role.get("rol_1")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/roles/rol_1"
    end
  end

  describe "create/1" do
    test "posts the role" do
      stub_request(%{"id" => "rol_1", "name" => "admin"})

      assert {:ok, %{"id" => "rol_1"}} =
               Role.create(%{name: "admin", description: "Can do anything"})

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/roles"
      assert request.body == %{"name" => "admin", "description" => "Can do anything"}
    end
  end

  describe "update/2" do
    test "patches the role" do
      stub_request(%{"id" => "rol_1"})

      assert {:ok, _} = Role.update("rol_1", %{description: "Updated"})

      request = assert_receive_request()
      assert request.method == "PATCH"
      assert request.path == "/api/v2/roles/rol_1"
      assert request.body == %{"description" => "Updated"}
    end
  end

  describe "delete/1" do
    test "deletes the role and returns :ok on Auth0's empty 200" do
      stub_status(200)

      assert :ok = Role.delete("rol_1")

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/roles/rol_1"
    end
  end

  describe "permissions/2" do
    test "gets the role's permissions" do
      stub_request([@permission])

      assert {:ok, [@permission]} == Role.permissions("rol_1")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/roles/rol_1/permissions"
    end

    test "passes through pagination" do
      stub_request([])
      Role.permissions("rol_1", per_page: 25)

      assert assert_receive_request().query == %{"per_page" => "25"}
    end
  end

  describe "add_permissions/2" do
    test "posts permissions given as tuples" do
      stub_status(201)

      assert :ok = Role.add_permissions("rol_1", [{"https://api.example.com", "read:users"}])

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/roles/rol_1/permissions"
      assert request.body == %{"permissions" => [@permission]}
    end

    test "the tuple shorthand and the map form send identical bodies" do
      stub_status(201)
      Role.add_permissions("rol_1", [{"https://api.example.com", "read:users"}])
      from_tuple = assert_receive_request().body

      stub_status(201)

      Role.add_permissions("rol_1", [
        %{resource_server_identifier: "https://api.example.com", permission_name: "read:users"}
      ])

      assert assert_receive_request().body == from_tuple
    end

    test "a string-keyed map read back from Auth0 round-trips" do
      stub_status(201)

      assert :ok = Role.add_permissions("rol_1", [@permission])

      assert assert_receive_request().body == %{"permissions" => [@permission]}
    end

    test "sends several permissions in one call" do
      stub_status(201)

      Role.add_permissions("rol_1", [
        {"https://api.example.com", "read:users"},
        {"https://api.example.com", "write:users"}
      ])

      assert %{"permissions" => [_, _]} = assert_receive_request().body
    end
  end

  describe "remove_permissions/2" do
    test "sends the permissions in the body of a DELETE" do
      stub_status(200)

      assert :ok = Role.remove_permissions("rol_1", [{"https://api.example.com", "read:users"}])

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/roles/rol_1/permissions"
      assert request.body == %{"permissions" => [@permission]}
    end
  end

  describe "users/2" do
    test "gets the role's users" do
      stub_request([%{"user_id" => "auth0|1"}])

      assert {:ok, [%{"user_id" => "auth0|1"}]} = Role.users("rol_1")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/roles/rol_1/users"
    end

    test "supports checkpoint pagination" do
      stub_request([])
      Role.users("rol_1", from: "cursor", take: 50)

      assert assert_receive_request().query == %{"from" => "cursor", "take" => "50"}
    end
  end

  describe "add_users/2" do
    test "posts the user ids and returns :ok on Auth0's empty 200" do
      stub_status(200)

      assert :ok = Role.add_users("rol_1", ["auth0|1", "auth0|2"])

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/roles/rol_1/users"
      assert request.body == %{"users" => ["auth0|1", "auth0|2"]}
    end
  end

  describe "groups/2" do
    test "gets the role's groups" do
      stub_request([%{"id" => "grp_1"}])

      assert {:ok, [%{"id" => "grp_1"}]} = Role.groups("rol_1")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/roles/rol_1/groups"
    end
  end

  describe "add_groups/2" do
    test "posts the group ids" do
      stub_status(204)

      assert :ok = Role.add_groups("rol_1", ["grp_1"])

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/roles/rol_1/groups"
      assert request.body == %{"groups" => ["grp_1"]}
    end
  end

  describe "remove_groups/2" do
    test "sends the group ids in the body of a DELETE" do
      stub_status(204)

      assert :ok = Role.remove_groups("rol_1", ["grp_1"])

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/roles/rol_1/groups"
      assert request.body == %{"groups" => ["grp_1"]}
    end
  end

  describe "authorization" do
    test "sends the management token" do
      stub_request([])
      Role.all()

      assert {"authorization", "Bearer TESTTOKEN"} in assert_receive_request().headers
    end
  end
end
