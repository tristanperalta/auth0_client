defmodule Auth0Ex.Authentication.LoginTest do
  use ExUnit.Case, async: true
  use Auth0Ex.ReqCase

  alias Auth0Ex.Authentication.Login

  describe "social/3,4" do
    test "posts to the legacy access_token endpoint with the default scope" do
      stub_request(%{"access_token" => "a_token"})

      assert {:ok, %{"access_token" => "a_token"}} =
               Login.social("an_id", "a_provider_token", "facebook")

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/oauth/access_token"

      assert request.body == %{
               "client_id" => "an_id",
               "access_token" => "a_provider_token",
               "connection" => "facebook",
               "scope" => "openid"
             }
    end

    test "posts the given scope" do
      stub_request(%{"access_token" => "a_token"})

      assert {:ok, _} =
               Login.social("an_id", "a_provider_token", "google", "openid profile email")

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/oauth/access_token"

      assert request.body == %{
               "client_id" => "an_id",
               "access_token" => "a_provider_token",
               "connection" => "google",
               "scope" => "openid profile email"
             }
    end

    test "sends no authorization header" do
      stub_request(%{"access_token" => "a_token"})

      assert {:ok, _} = Login.social("an_id", "a_provider_token", "facebook")

      headers = assert_receive_request().headers
      refute List.keymember?(headers, "authorization", 0)
    end
  end

  describe "database/5,6" do
    test "posts to the legacy resource owner endpoint" do
      stub_request(%{"id_token" => "an_id_token"})

      assert {:ok, %{"id_token" => "an_id_token"}} =
               Login.database("an_id", "samar", "samarpwd", "dev", "password")

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/oauth/ro"

      assert request.body == %{
               "client_id" => "an_id",
               "username" => "samar",
               "password" => "samarpwd",
               "connection" => "dev",
               "grant_type" => "password"
             }
    end

    test "merges the optional params into the payload" do
      stub_request(%{"id_token" => "an_id_token"})

      assert {:ok, _} =
               Login.database("an_id", "samar", "samarpwd", "dev", "password", %{
                 scope: "openid app_metadata",
                 device: "ios"
               })

      request = assert_receive_request()

      assert request.body == %{
               "client_id" => "an_id",
               "username" => "samar",
               "password" => "samarpwd",
               "connection" => "dev",
               "grant_type" => "password",
               "scope" => "openid app_metadata",
               "device" => "ios"
             }
    end

    test "lets the optional params override the base payload" do
      stub_request(%{"id_token" => "an_id_token"})

      assert {:ok, _} =
               Login.database("an_id", "samar", "samarpwd", "dev", "password", %{
                 connection: "other"
               })

      assert assert_receive_request().body["connection"] == "other"
    end

    test "sends no authorization header" do
      stub_request(%{"id_token" => "an_id_token"})

      assert {:ok, _} = Login.database("an_id", "samar", "samarpwd", "dev", "password")

      headers = assert_receive_request().headers
      refute List.keymember?(headers, "authorization", 0)
    end
  end
end
