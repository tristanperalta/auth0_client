defmodule Auth0Client.Management.SessionTest do
  use ExUnit.Case, async: true
  use Auth0Client.ReqCase

  alias Auth0Client.Management.Session

  describe "get/1" do
    test "gets a single session" do
      stub_request(%{"id" => "sess_1", "user_id" => "auth0|1"})

      assert {:ok, %{"id" => "sess_1"}} = Session.get("sess_1")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/sessions/sess_1"
    end
  end

  describe "update/2" do
    test "patches the metadata" do
      stub_request(%{"id" => "sess_1"})

      assert {:ok, _} = Session.update("sess_1", %{session_metadata: %{device: "laptop"}})

      request = assert_receive_request()
      assert request.method == "PATCH"
      assert request.path == "/api/v2/sessions/sess_1"
      assert request.body == %{"session_metadata" => %{"device" => "laptop"}}
    end

    # An explicit null is how you clear metadata, so it must survive rather than being
    # pruned — the reason nil-pruning is scoped away from Management PATCH bodies.
    test "sends an explicit null when clearing metadata" do
      stub_request(%{"id" => "sess_1"})

      assert {:ok, _} = Session.update("sess_1", %{session_metadata: nil})

      assert assert_receive_request().body == %{"session_metadata" => nil}
    end
  end

  # delete/1 leaves the refresh tokens alive; revoke/1 does not. Different paths,
  # different consequences.
  describe "delete/1 and revoke/1" do
    test "delete/1 deletes the session and accepts a 202" do
      stub_status(202)

      assert :ok = Session.delete("sess_1")

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/sessions/sess_1"
    end

    test "revoke/1 posts to the revoke path and accepts a 202" do
      stub_status(202)

      assert :ok = Session.revoke("sess_1")

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/sessions/sess_1/revoke"
    end
  end
end
