defmodule Auth0Ex.Management.GroupTest do
  use ExUnit.Case, async: true
  use Auth0Ex.ReqCase

  alias Auth0Ex.Management.Group

  describe "all/0,1" do
    test "gets all groups" do
      stub_request([%{"id" => "grp_1"}])

      assert {:ok, [%{"id" => "grp_1"}]} = Group.all()

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/groups"
      assert request.query_string == ""
    end

    test "accepts filters as a keyword list" do
      stub_request([])

      assert {:ok, []} = Group.all(connection_id: "con_abc123", search: "eng")

      assert assert_receive_request().query == %{
               "connection_id" => "con_abc123",
               "search" => "eng"
             }
    end
  end

  describe "get/1" do
    test "gets a single group" do
      stub_request(%{"id" => "grp_1", "name" => "Engineering"})

      assert {:ok, %{"id" => "grp_1"}} = Group.get("grp_1")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/groups/grp_1"
    end
  end

  describe "delete/1" do
    test "deletes and returns :ok on 204" do
      stub_request(fn conn -> Plug.Conn.send_resp(conn, 204, "") end)

      assert :ok = Group.delete("grp_1")

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/groups/grp_1"
      assert request.query_string == ""
    end
  end

  describe "members/2" do
    test "lists the users in a group" do
      stub_request(%{"members" => [%{"user_id" => "auth0|1"}]})

      assert {:ok, %{"members" => _}} = Group.members("grp_1")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/groups/grp_1/members"
    end

    test "supports checkpoint pagination" do
      stub_request(%{})
      Group.members("grp_1", take: 50)

      assert assert_receive_request().query == %{"take" => "50"}
    end
  end

  describe "roles/2" do
    test "lists the roles a group carries" do
      stub_request(%{"roles" => [%{"id" => "rol_1"}]})

      assert {:ok, %{"roles" => _}} = Group.roles("grp_1")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/groups/grp_1/roles"
    end
  end

  describe "add_roles/2" do
    test "posts the role ids and returns :ok on 204" do
      stub_request(fn conn -> Plug.Conn.send_resp(conn, 204, "") end)

      assert :ok = Group.add_roles("grp_1", ["rol_1", "rol_2"])

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/groups/grp_1/roles"
      assert request.body == %{"roles" => ["rol_1", "rol_2"]}
    end
  end

  describe "remove_roles/2" do
    # Auth0 documents a request body on this DELETE. do_delete/3 would silently turn
    # the payload into query params instead, so the body assertion is the point.
    test "sends the role ids in the DELETE body, not the query string" do
      stub_request(fn conn -> Plug.Conn.send_resp(conn, 204, "") end)

      assert :ok = Group.remove_roles("grp_1", ["rol_1"])

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/groups/grp_1/roles"
      assert request.query_string == ""
      assert request.body == %{"roles" => ["rol_1"]}
    end
  end
end
