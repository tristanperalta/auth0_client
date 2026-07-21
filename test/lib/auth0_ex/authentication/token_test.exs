defmodule Auth0Ex.Authentication.TokenTest do
  use ExUnit.Case, async: true
  use Auth0Ex.ReqCase

  alias Auth0Ex.Authentication.Token

  describe "auth_code/3,4" do
    test "omits redirect_uri entirely when it is not given" do
      stub_request(%{"access_token" => "a_token"})

      assert {:ok, %{"access_token" => "a_token"}} =
               Token.auth_code("an_id", "a_secret", "a_code")

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/oauth/token"

      assert request.body == %{
               "client_id" => "an_id",
               "client_secret" => "a_secret",
               "code" => "a_code",
               "grant_type" => "authorization_code"
             }

      refute Map.has_key?(request.body, "redirect_uri")
    end

    test "posts the given redirect_uri" do
      stub_request(%{"access_token" => "a_token"})

      assert {:ok, _} =
               Token.auth_code("an_id", "a_secret", "a_code", "https://example.com/callback")

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/oauth/token"

      assert request.body == %{
               "client_id" => "an_id",
               "client_secret" => "a_secret",
               "code" => "a_code",
               "redirect_uri" => "https://example.com/callback",
               "grant_type" => "authorization_code"
             }
    end
  end

  describe "auth_code_pkce/3,4" do
    test "sends no client secret for a public client" do
      stub_request(%{"access_token" => "a_token"})

      assert {:ok, %{"access_token" => "a_token"}} =
               Token.auth_code_pkce("an_id", "a_code", "a_verifier")

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/oauth/token"

      assert request.body == %{
               "client_id" => "an_id",
               "code" => "a_code",
               "code_verifier" => "a_verifier",
               "grant_type" => "authorization_code"
             }

      refute Map.has_key?(request.body, "client_secret")
      refute Map.has_key?(request.body, "redirect_uri")
    end

    test "posts a redirect_uri given in opts" do
      stub_request(%{"access_token" => "a_token"})

      assert {:ok, _} =
               Token.auth_code_pkce("an_id", "a_code", "a_verifier", %{
                 redirect_uri: "https://example.com/callback"
               })

      request = assert_receive_request()

      assert request.body == %{
               "client_id" => "an_id",
               "code" => "a_code",
               "code_verifier" => "a_verifier",
               "redirect_uri" => "https://example.com/callback",
               "grant_type" => "authorization_code"
             }
    end

    test "posts a client_secret given in opts for a confidential client" do
      stub_request(%{"access_token" => "a_token"})

      assert {:ok, _} =
               Token.auth_code_pkce("an_id", "a_code", "a_verifier", %{client_secret: "a_secret"})

      assert assert_receive_request().body == %{
               "client_id" => "an_id",
               "code" => "a_code",
               "code_verifier" => "a_verifier",
               "client_secret" => "a_secret",
               "grant_type" => "authorization_code"
             }
    end
  end

  describe "client_credentials/3" do
    test "posts the client credentials grant" do
      stub_request(%{"access_token" => "a_token"})

      assert {:ok, %{"access_token" => "a_token"}} =
               Token.client_credentials("an_id", "a_secret", "an_audience")

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/oauth/token"

      assert request.body == %{
               "client_id" => "an_id",
               "client_secret" => "a_secret",
               "audience" => "an_audience",
               "grant_type" => "client_credentials"
             }
    end
  end

  describe "authorization" do
    test "sends no authorization header" do
      stub_request(%{"access_token" => "a_token"})

      assert {:ok, _} = Token.client_credentials("an_id", "a_secret", "an_audience")

      headers = assert_receive_request().headers
      refute List.keymember?(headers, "authorization", 0)
    end
  end

  describe "paths" do
    test "hang off the tenant root with no /api/v2 prefix" do
      stub_request(%{"access_token" => "a_token"})

      assert {:ok, _} = Token.client_credentials("an_id", "a_secret", "an_audience")

      refute assert_receive_request().path =~ "/api/v2"
    end
  end
end
