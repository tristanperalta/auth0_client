defmodule Auth0Client.Management.OrganizationTest do
  use ExUnit.Case, async: true
  use Auth0Client.ReqCase

  alias Auth0Client.Management.Organization

  @org_id "org_abc123"
  @user_id "auth0|user1"
  @encoded_user_id "auth0%7Cuser1"

  describe "all/1" do
    test "gets all organizations" do
      stub_request([%{"id" => @org_id, "name" => "acme-corp"}])

      assert {:ok, [%{"id" => @org_id}]} = Organization.all()

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/organizations"
      assert request.query_string == ""
    end

    test "supports offset pagination and sort" do
      stub_request([])
      Organization.all(page: 2, per_page: 50, include_totals: true, sort: "name:1")

      assert assert_receive_request().query == %{
               "page" => "2",
               "per_page" => "50",
               "include_totals" => "true",
               "sort" => "name:1"
             }
    end

    test "supports checkpoint pagination" do
      stub_request([])
      Organization.all(%{from: "cursor", take: 25})

      assert assert_receive_request().query == %{"from" => "cursor", "take" => "25"}
    end
  end

  describe "get/1 and get_by_name/1" do
    test "gets an organization by id" do
      stub_request(%{"id" => @org_id})

      assert {:ok, %{"id" => @org_id}} = Organization.get(@org_id)

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/organizations/#{@org_id}"
    end

    test "gets an organization by name, on the /name path" do
      stub_request(%{"name" => "acme-corp"})

      assert {:ok, %{"name" => "acme-corp"}} = Organization.get_by_name("acme-corp")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/organizations/name/acme-corp"
    end
  end

  describe "create/1, update/2, delete/1" do
    test "posts the organization" do
      stub_request(%{"id" => @org_id})

      assert {:ok, %{"id" => @org_id}} =
               Organization.create(%{name: "acme-corp", display_name: "Acme Corp"})

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/organizations"
      assert request.body == %{"name" => "acme-corp", "display_name" => "Acme Corp"}
    end

    test "patches the organization" do
      stub_request(%{"id" => @org_id})

      assert {:ok, _} = Organization.update(@org_id, %{display_name: "Acme Corporation"})

      request = assert_receive_request()
      assert request.method == "PATCH"
      assert request.path == "/api/v2/organizations/#{@org_id}"
      assert request.body == %{"display_name" => "Acme Corporation"}
    end

    test "deletes the organization" do
      stub_status(204)

      assert :ok = Organization.delete(@org_id)

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/organizations/#{@org_id}"
    end
  end

  describe "members" do
    test "members/2 lists them" do
      stub_request([%{"user_id" => @user_id}])

      assert {:ok, [%{"user_id" => @user_id}]} = Organization.members(@org_id)

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/organizations/#{@org_id}/members"
    end

    test "members/2 supports checkpoint pagination" do
      stub_request([])
      Organization.members(@org_id, take: 50)

      assert assert_receive_request().query == %{"take" => "50"}
    end

    test "add_members/2 posts the user ids" do
      stub_status(204)

      assert :ok = Organization.add_members(@org_id, [@user_id, "auth0|user2"])

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/organizations/#{@org_id}/members"
      assert request.body == %{"members" => [@user_id, "auth0|user2"]}
    end

    test "remove_members/2 sends the user ids in the body of a DELETE" do
      stub_status(204)

      assert :ok = Organization.remove_members(@org_id, [@user_id])

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/organizations/#{@org_id}/members"
      assert request.body == %{"members" => [@user_id]}
    end
  end

  describe "member roles" do
    test "member_roles/3 lists a member's roles" do
      stub_request([%{"id" => "rol_1"}])

      assert {:ok, [%{"id" => "rol_1"}]} = Organization.member_roles(@org_id, @user_id)

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/organizations/#{@org_id}/members/#{@encoded_user_id}/roles"
    end

    test "assign_member_roles/3 posts the role ids" do
      stub_status(204)

      assert :ok = Organization.assign_member_roles(@org_id, @user_id, ["rol_1"])

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/organizations/#{@org_id}/members/#{@encoded_user_id}/roles"
      assert request.body == %{"roles" => ["rol_1"]}
    end

    test "remove_member_roles/3 sends the role ids in the body of a DELETE" do
      stub_status(204)

      assert :ok = Organization.remove_member_roles(@org_id, @user_id, ["rol_1"])

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/organizations/#{@org_id}/members/#{@encoded_user_id}/roles"
      assert request.body == %{"roles" => ["rol_1"]}
    end

    test "member_effective_roles/3 includes roles inherited through groups" do
      stub_request([])
      Organization.member_effective_roles(@org_id, @user_id, take: 10)

      request = assert_receive_request()

      assert request.path ==
               "/api/v2/organizations/#{@org_id}/members/#{@encoded_user_id}/effective-roles"

      assert request.query == %{"take" => "10"}
    end

    test "member_effective_role_source_groups/3 explains where a role comes from" do
      stub_request([])
      Organization.member_effective_role_source_groups(@org_id, @user_id, role_id: "rol_1")

      request = assert_receive_request()

      assert request.path ==
               "/api/v2/organizations/#{@org_id}/members/#{@encoded_user_id}/effective-roles/sources/groups"

      assert request.query == %{"role_id" => "rol_1"}
    end

    test "role_members/3 is the inverse of member_roles/3, not a duplicate" do
      stub_request([])
      Organization.role_members(@org_id, "rol_1")
      role_members_path = assert_receive_request().path

      stub_request([])
      Organization.member_roles(@org_id, @user_id)
      member_roles_path = assert_receive_request().path

      assert role_members_path == "/api/v2/organizations/#{@org_id}/roles/rol_1/members"

      assert member_roles_path ==
               "/api/v2/organizations/#{@org_id}/members/#{@encoded_user_id}/roles"

      refute role_members_path == member_roles_path
    end
  end

  describe "invitations" do
    test "invitations/2 lists them" do
      stub_request([%{"id" => "inv_1"}])

      assert {:ok, [%{"id" => "inv_1"}]} = Organization.invitations(@org_id)

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/organizations/#{@org_id}/invitations"
    end

    test "invitation/3 gets one, with field filtering" do
      stub_request(%{"id" => "inv_1"})

      assert {:ok, _} = Organization.invitation(@org_id, "inv_1", fields: "id,invitee")

      request = assert_receive_request()
      assert request.path == "/api/v2/organizations/#{@org_id}/invitations/inv_1"
      assert request.query == %{"fields" => "id,invitee"}
    end

    # Auth0 answers this one with 200 and a body, unlike the 204 mutations around
    # it, so it returns {:ok, invitation} rather than a bare :ok.
    test "create_invitation/2 returns the created invitation" do
      stub_request(%{"id" => "inv_1", "invitation_url" => "https://example.com/i"})

      assert {:ok, %{"id" => "inv_1", "invitation_url" => _}} =
               Organization.create_invitation(@org_id, %{
                 inviter: %{name: "Admin"},
                 invitee: %{email: "new@example.com"},
                 client_id: "a_client_id"
               })

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/organizations/#{@org_id}/invitations"

      assert request.body == %{
               "inviter" => %{"name" => "Admin"},
               "invitee" => %{"email" => "new@example.com"},
               "client_id" => "a_client_id"
             }
    end

    test "delete_invitation/2 revokes it" do
      stub_status(204)

      assert :ok = Organization.delete_invitation(@org_id, "inv_1")

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/organizations/#{@org_id}/invitations/inv_1"
      assert request.body == ""
    end
  end

  describe "connections" do
    test "connections/2 lists them and supports is_enabled" do
      stub_request([%{"connection_id" => "con_1"}])

      assert {:ok, [%{"connection_id" => "con_1"}]} =
               Organization.connections(@org_id, is_enabled: true)

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/organizations/#{@org_id}/connections"
      assert request.query == %{"is_enabled" => "true"}
    end

    test "connection/2 gets one" do
      stub_request(%{"connection_id" => "con_1"})

      assert {:ok, _} = Organization.connection(@org_id, "con_1")

      assert assert_receive_request().path ==
               "/api/v2/organizations/#{@org_id}/connections/con_1"
    end

    test "add_connection/2 posts the body" do
      stub_request(%{"connection_id" => "con_1"})

      assert {:ok, _} =
               Organization.add_connection(@org_id, %{
                 connection_id: "con_1",
                 assign_membership_on_login: true
               })

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/organizations/#{@org_id}/connections"

      assert request.body == %{
               "connection_id" => "con_1",
               "assign_membership_on_login" => true
             }
    end

    test "update_connection/3 patches it" do
      stub_request(%{"connection_id" => "con_1"})

      assert {:ok, _} = Organization.update_connection(@org_id, "con_1", %{show_as_button: false})

      request = assert_receive_request()
      assert request.method == "PATCH"
      assert request.path == "/api/v2/organizations/#{@org_id}/connections/con_1"
      assert request.body == %{"show_as_button" => false}
    end

    test "remove_connection/2 deletes it" do
      stub_status(204)

      assert :ok = Organization.remove_connection(@org_id, "con_1")

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/organizations/#{@org_id}/connections/con_1"
    end
  end

  describe "client grants" do
    test "client_grants/2 lists them and filters by audience" do
      stub_request([%{"id" => "cgr_1"}])

      assert {:ok, [%{"id" => "cgr_1"}]} =
               Organization.client_grants(@org_id, audience: "https://api.example.com")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/organizations/#{@org_id}/client-grants"
      assert request.query == %{"audience" => "https://api.example.com"}
    end

    test "add_client_grant/2 posts the grant id" do
      stub_request(%{"id" => "cgr_1"})

      assert {:ok, _} = Organization.add_client_grant(@org_id, "cgr_1")

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/organizations/#{@org_id}/client-grants"
      assert request.body == %{"grant_id" => "cgr_1"}
    end

    test "remove_client_grant/2 takes the id in the path, not the body" do
      stub_status(204)

      assert :ok = Organization.remove_client_grant(@org_id, "cgr_1")

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/organizations/#{@org_id}/client-grants/cgr_1"
      assert request.body == ""
    end
  end

  describe "discovery domains" do
    test "discovery_domains/2 lists them with checkpoint pagination" do
      stub_request([%{"domain" => "acme.com"}])

      assert {:ok, [%{"domain" => "acme.com"}]} =
               Organization.discovery_domains(@org_id, take: 10)

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/organizations/#{@org_id}/discovery-domains"
      assert request.query == %{"take" => "10"}
    end

    test "discovery_domain/2 gets one by id" do
      stub_request(%{"id" => "dom_1"})

      assert {:ok, _} = Organization.discovery_domain(@org_id, "dom_1")

      assert assert_receive_request().path ==
               "/api/v2/organizations/#{@org_id}/discovery-domains/dom_1"
    end

    test "discovery_domain_by_name/2 uses the /name path" do
      stub_request(%{"domain" => "acme.com"})

      assert {:ok, _} = Organization.discovery_domain_by_name(@org_id, "acme.com")

      assert assert_receive_request().path ==
               "/api/v2/organizations/#{@org_id}/discovery-domains/name/acme.com"
    end

    test "add_discovery_domain/2 posts the domain" do
      stub_request(%{"id" => "dom_1"})

      assert {:ok, _} = Organization.add_discovery_domain(@org_id, %{domain: "acme.com"})

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/organizations/#{@org_id}/discovery-domains"
      assert request.body == %{"domain" => "acme.com"}
    end

    test "update_discovery_domain/3 patches it" do
      stub_request(%{"id" => "dom_1"})

      assert {:ok, _} =
               Organization.update_discovery_domain(@org_id, "dom_1", %{
                 use_for_organization_discovery: true
               })

      request = assert_receive_request()
      assert request.method == "PATCH"
      assert request.path == "/api/v2/organizations/#{@org_id}/discovery-domains/dom_1"
      assert request.body == %{"use_for_organization_discovery" => true}
    end

    test "remove_discovery_domain/2 deletes it" do
      stub_status(204)

      assert :ok = Organization.remove_discovery_domain(@org_id, "dom_1")

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/organizations/#{@org_id}/discovery-domains/dom_1"
    end
  end

  describe "groups" do
    test "groups/2 lists the organization's groups" do
      stub_request([%{"id" => "grp_1"}])

      assert {:ok, [%{"id" => "grp_1"}]} = Organization.groups(@org_id)

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/organizations/#{@org_id}/groups"
    end

    test "group_roles/3 lists the roles a group grants" do
      stub_request([%{"id" => "rol_1"}])

      assert {:ok, [%{"id" => "rol_1"}]} = Organization.group_roles(@org_id, "grp_1")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/organizations/#{@org_id}/groups/grp_1/roles"
    end

    test "assign_group_roles/3 posts the role ids" do
      stub_status(204)

      assert :ok = Organization.assign_group_roles(@org_id, "grp_1", ["rol_1"])

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/organizations/#{@org_id}/groups/grp_1/roles"
      assert request.body == %{"roles" => ["rol_1"]}
    end

    test "remove_group_roles/3 sends the role ids in the body of a DELETE" do
      stub_status(204)

      assert :ok = Organization.remove_group_roles(@org_id, "grp_1", ["rol_1"])

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/organizations/#{@org_id}/groups/grp_1/roles"
      assert request.body == %{"roles" => ["rol_1"]}
    end
  end

  describe "authorization" do
    test "sends the management token" do
      stub_request([])
      Organization.all()

      assert {"authorization", "Bearer TESTTOKEN"} in assert_receive_request().headers
    end
  end
end
