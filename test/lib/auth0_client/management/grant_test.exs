defmodule Auth0Client.Management.GrantTest do
  use ExUnit.Case, async: true
  use Auth0Client.ReqCase

  alias Auth0Client.Management.Grant

  defp empty(status), do: fn conn -> Plug.Conn.send_resp(conn, status, "") end

  describe "all/1" do
    test "gets all grants" do
      stub_request([%{"id" => "cgr_1", "clientID" => "abc"}])

      assert {:ok, [%{"id" => "cgr_1"}]} = Grant.all()

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/grants"
      assert request.query_string == ""
    end

    test "filters by user, client and audience" do
      stub_request([])

      Grant.all(user_id: "auth0|1", client_id: "abc", audience: "https://api.example.com")

      assert assert_receive_request().query == %{
               "user_id" => "auth0|1",
               "client_id" => "abc",
               "audience" => "https://api.example.com"
             }
    end

    test "paginates" do
      stub_request([])
      Grant.all(%{page: 1, per_page: 25, include_totals: true})

      assert assert_receive_request().query == %{
               "page" => "1",
               "per_page" => "25",
               "include_totals" => "true"
             }
    end
  end

  describe "delete/1" do
    test "deletes one grant by id, in the path" do
      stub_request(empty(204))

      assert :ok = Grant.delete("cgr_1")

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/grants/cgr_1"
      assert request.query_string == ""
    end
  end

  describe "delete_by_user/1" do
    # Auth0 takes the user id as a query parameter here, not a path segment —
    # the shape most likely to be got wrong.
    test "sends user_id as a query param, not a path segment" do
      stub_request(empty(204))

      assert :ok = Grant.delete_by_user("auth0|abc123")

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/grants"
      assert request.query == %{"user_id" => "auth0|abc123"}
    end

    test "does not put the user id in the path" do
      stub_request(empty(204))
      Grant.delete_by_user("auth0|abc123")

      refute assert_receive_request().path =~ "auth0|abc123"
    end
  end

  describe "authorization" do
    test "sends the management token" do
      stub_request([])
      Grant.all()

      assert {"authorization", "Bearer TESTTOKEN"} in assert_receive_request().headers
    end
  end
end
