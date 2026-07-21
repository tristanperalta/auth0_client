defmodule Auth0Ex.Management.UserBlockTest do
  use ExUnit.Case, async: true
  use Auth0Ex.ReqCase

  alias Auth0Ex.Management.UserBlock

  describe "get/1" do
    test "gets the blocks for an identifier" do
      stub_request(%{"blocked_for" => []})

      assert {:ok, %{"blocked_for" => []}} = UserBlock.get("some@example.com")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/user-blocks"
      assert request.query == %{"identifier" => "some@example.com"}
    end
  end

  describe "get_user_block/1" do
    test "gets the blocks for a user id" do
      stub_request(%{"blocked_for" => [%{"identifier" => "some@example.com"}]})

      assert {:ok, %{"blocked_for" => [%{"identifier" => "some@example.com"}]}} =
               UserBlock.get_user_block("auth0|234234")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/user-blocks/auth0|234234"
      assert request.query_string == ""
    end
  end

  describe "unblock/1" do
    test "deletes the blocks for an identifier and returns :ok on 204" do
      stub_request(fn conn -> Plug.Conn.send_resp(conn, 204, "") end)

      assert :ok = UserBlock.unblock("some@example.com")

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/user-blocks"
      assert request.query == %{"identifier" => "some@example.com"}
    end
  end

  describe "unblock_user/1" do
    test "deletes the user's blocks and returns :ok on 204" do
      stub_request(fn conn -> Plug.Conn.send_resp(conn, 204, "") end)

      assert :ok = UserBlock.unblock_user("auth0|2342")

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/user-blocks/auth0|2342"
      assert request.body == ""
    end
  end

  describe "authorization" do
    test "sends the configured management token" do
      stub_request(%{"blocked_for" => []})

      assert {:ok, _} = UserBlock.get_user_block("auth0|2342")

      headers = assert_receive_request().headers
      assert {"authorization", "Bearer TESTTOKEN"} in headers
    end
  end
end
