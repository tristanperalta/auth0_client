defmodule Auth0Ex.Management.BlacklistTest do
  use ExUnit.Case, async: true
  use Auth0Ex.ReqCase

  alias Auth0Ex.Management.Blacklist

  describe "get/1" do
    test "gets the blacklisted tokens for an audience" do
      stub_request([%{"aud" => "some_aud", "jti" => "some_jti"}])

      assert {:ok, [%{"aud" => "some_aud", "jti" => "some_jti"}]} = Blacklist.get("some_aud")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/blacklists/tokens"
      assert request.query == %{"aud" => "some_aud"}
      assert request.body == ""
    end
  end

  describe "blacklist/1" do
    test "posts the body" do
      stub_request(%{"aud" => "some_aud", "jti" => "some_jti"})

      assert {:ok, %{"jti" => "some_jti"}} =
               Blacklist.blacklist(%{aud: "some_aud", jti: "some_jti"})

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/blacklists/tokens"
      assert request.body == %{"aud" => "some_aud", "jti" => "some_jti"}
    end

    test "accepts a keyword list body" do
      stub_request(%{"aud" => "some_aud", "jti" => "some_jti"})

      assert {:ok, _} = Blacklist.blacklist(aud: "some_aud", jti: "some_jti")

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/blacklists/tokens"
      assert request.body == %{"aud" => "some_aud", "jti" => "some_jti"}
    end
  end
end
