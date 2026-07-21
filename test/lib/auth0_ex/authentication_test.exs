defmodule Auth0Ex.AuthenticationTest do
  use ExUnit.Case, async: true
  use Auth0Ex.ReqCase

  alias Auth0Ex.Authentication

  describe "signup/4,5" do
    test "posts the signup payload" do
      stub_request(%{"email" => "samar@example.com"})

      assert {:ok, %{"email" => "samar@example.com"}} =
               Authentication.signup(
                 "an_id",
                 "samar@example.com",
                 "a_password",
                 "Username-Password-Authentication"
               )

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/dbconnections/signup"

      assert request.body == %{
               "client_id" => "an_id",
               "email" => "samar@example.com",
               "password" => "a_password",
               "connection" => "Username-Password-Authentication"
             }
    end

    test "merges the extra params into the payload" do
      stub_request(%{"email" => "samar@example.com"})

      assert {:ok, _} =
               Authentication.signup(
                 "an_id",
                 "samar@example.com",
                 "a_password",
                 "Username-Password-Authentication",
                 %{user_metadata: %{plan: "silver"}}
               )

      request = assert_receive_request()

      assert request.body == %{
               "client_id" => "an_id",
               "email" => "samar@example.com",
               "password" => "a_password",
               "connection" => "Username-Password-Authentication",
               "user_metadata" => %{"plan" => "silver"}
             }
    end

    test "lets the extra params override the base payload" do
      stub_request(%{})

      assert {:ok, _} =
               Authentication.signup("an_id", "samar@example.com", "a_password", "conn", %{
                 connection: "other"
               })

      assert assert_receive_request().body["connection"] == "other"
    end
  end

  describe "change_password/3" do
    test "posts the change password payload" do
      stub_request("We've just sent you an email to reset your password.")

      assert {:ok, _} =
               Authentication.change_password(
                 "an_id",
                 "samar@example.com",
                 "Username-Password-Authentication"
               )

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/dbconnections/change_password"

      assert request.body == %{
               "client_id" => "an_id",
               "email" => "samar@example.com",
               "connection" => "Username-Password-Authentication"
             }
    end
  end

  describe "userinfo/1" do
    test "gets userinfo with the access token as a query param" do
      stub_request(%{"sub" => "auth0|abc123"})

      assert {:ok, %{"sub" => "auth0|abc123"}} = Authentication.userinfo("an_access_token")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/userinfo"
      assert request.query == %{"access_token" => "an_access_token"}
      assert request.body == ""
    end
  end

  describe "tokeninfo/1" do
    test "posts the id token to the legacy tokeninfo endpoint" do
      stub_request(%{"sub" => "auth0|abc123"})

      assert {:ok, %{"sub" => "auth0|abc123"}} = Authentication.tokeninfo("an_id_token")

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/tokeninfo"
      assert request.body == %{"id_token" => "an_id_token"}
    end
  end

  describe "authorization" do
    test "sends no authorization header" do
      stub_request(%{"sub" => "auth0|abc123"})

      assert {:ok, _} = Authentication.userinfo("an_access_token")

      headers = assert_receive_request().headers
      refute List.keymember?(headers, "authorization", 0)
    end
  end

  describe "paths" do
    test "hang off the tenant root with no /api/v2 prefix" do
      stub_request(%{"sub" => "auth0|abc123"})

      assert {:ok, _} = Authentication.tokeninfo("an_id_token")

      refute assert_receive_request().path =~ "/api/v2"
    end
  end
end
