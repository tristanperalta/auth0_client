defmodule Auth0Client.AuthenticationTest do
  use ExUnit.Case, async: true
  use Auth0Client.ReqCase

  alias Auth0Client.Authentication

  describe "signup/3,4" do
    test "posts the signup payload with the email in opts" do
      stub_request(%{"email" => "samar@example.com"})

      assert {:ok, %{"email" => "samar@example.com"}} =
               Authentication.signup(
                 "an_id",
                 "a_password",
                 "Username-Password-Authentication",
                 %{email: "samar@example.com"}
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

    # The point of the change: only password and connection are required, so a
    # phone-based connection no longer has to invent an email address.
    test "sends no email when the connection does not use one" do
      stub_request(%{})

      assert {:ok, _} =
               Authentication.signup("an_id", "a_password", "sms-conn", %{
                 phone_number: "+15551234567"
               })

      body = assert_receive_request().body
      assert body["phone_number"] == "+15551234567"
      refute Map.has_key?(body, "email")
    end

    test "works with no opts at all" do
      stub_request(%{})

      assert {:ok, _} = Authentication.signup("an_id", "a_password", "a_conn")

      assert assert_receive_request().body == %{
               "client_id" => "an_id",
               "password" => "a_password",
               "connection" => "a_conn"
             }
    end

    test "merges opts into the payload" do
      stub_request(%{"email" => "samar@example.com"})

      assert {:ok, _} =
               Authentication.signup("an_id", "a_password", "Username-Password-Authentication", %{
                 email: "samar@example.com",
                 user_metadata: %{plan: "silver"}
               })

      assert assert_receive_request().body == %{
               "client_id" => "an_id",
               "email" => "samar@example.com",
               "password" => "a_password",
               "connection" => "Username-Password-Authentication",
               "user_metadata" => %{"plan" => "silver"}
             }
    end

    test "lets opts override the base payload" do
      stub_request(%{})

      assert {:ok, _} =
               Authentication.signup("an_id", "a_password", "conn", %{connection: "other"})

      assert assert_receive_request().body["connection"] == "other"
    end

    # signup/4 changed meaning at the same arity: it used to be
    # (client_id, email, password, connection). The is_map guard is what turns an
    # unmigrated call into a loud failure rather than a silently wrong request.
    test "the old argument order raises rather than sending nonsense" do
      assert_raise FunctionClauseError, fn ->
        Authentication.signup("an_id", "samar@example.com", "a_password", "a_connection")
      end
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
    test "sends the access token as a bearer header, not a query param" do
      stub_request(%{"sub" => "auth0|abc123"})

      assert {:ok, %{"sub" => "auth0|abc123"}} = Authentication.userinfo("an_access_token")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/userinfo"
      assert request.body == ""
      assert {"authorization", "Bearer an_access_token"} in request.headers
    end

    test "does not leak the token into the query string" do
      stub_request(%{"sub" => "auth0|abc123"})

      assert {:ok, _} = Authentication.userinfo("an_access_token")

      request = assert_receive_request()
      assert request.query_string == ""
      refute request.query_string =~ "an_access_token"
    end
  end

  describe "passwordless_start/1" do
    test "posts the start request" do
      stub_request(%{"_id" => "1", "email" => "user@example.com"})

      assert {:ok, %{"_id" => "1"}} =
               Authentication.passwordless_start(%{
                 client_id: "a_client_id",
                 connection: "email",
                 email: "user@example.com",
                 send: "code"
               })

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/passwordless/start"

      assert request.body == %{
               "client_id" => "a_client_id",
               "connection" => "email",
               "email" => "user@example.com",
               "send" => "code"
             }
    end

    test "works for the sms connection" do
      stub_request(%{})

      Authentication.passwordless_start(%{
        client_id: "a_client_id",
        connection: "sms",
        phone_number: "+15551234567"
      })

      body = assert_receive_request().body
      assert body["connection"] == "sms"
      assert body["phone_number"] == "+15551234567"
    end

    # authParams is a nested object, which is why this endpoint is JSON rather
    # than form-encoded like the /oauth/token grants.
    test "carries a nested authParams through as JSON" do
      stub_request(%{})

      Authentication.passwordless_start(%{
        client_id: "a_client_id",
        connection: "email",
        email: "user@example.com",
        authParams: %{scope: "openid profile", state: "opaque"}
      })

      request = assert_receive_request()
      assert request.content_type == "application/json"

      assert request.body["authParams"] == %{
               "scope" => "openid profile",
               "state" => "opaque"
             }
    end
  end

  describe "discovery" do
    test "jwks/0 fetches the key set" do
      stub_request(%{"keys" => []})

      assert {:ok, %{"keys" => []}} = Authentication.jwks()

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/.well-known/jwks.json"
    end

    test "openid_configuration/0 fetches the discovery document" do
      stub_request(%{"issuer" => "https://brighterlink.auth0.com/"})

      assert {:ok, %{"issuer" => _}} = Authentication.openid_configuration()

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/.well-known/openid-configuration"
    end

    test "neither sends an authorization header" do
      for call <- [&Authentication.jwks/0, &Authentication.openid_configuration/0] do
        stub_request(%{})
        call.()

        refute List.keyfind(assert_receive_request().headers, "authorization", 0)
      end
    end
  end

  describe "encoding" do
    # Auth0 is split: /oauth/* takes form-encoded bodies, /dbconnections/* takes
    # JSON. These pin the JSON side, because form encoding cannot represent the
    # nested user_metadata that signup documents.
    test "signup is sent as JSON" do
      stub_request(%{"_id" => "1"})
      Authentication.signup("a_client_id", "pwd", "a_connection", %{email: "a@b.com"})

      assert assert_receive_request().content_type == "application/json"
    end

    test "change_password is sent as JSON" do
      stub_request(%{"_id" => "1"})
      Authentication.change_password("a_client_id", "a@b.com", "a_connection")

      assert assert_receive_request().content_type == "application/json"
    end

    test "nested user_metadata survives the round trip" do
      stub_request(%{"_id" => "1"})

      Authentication.signup("a_client_id", "pwd", "a_connection", %{
        email: "a@b.com",
        user_metadata: %{plan: "silver", team_id: "a111"}
      })

      assert assert_receive_request().body["user_metadata"] == %{
               "plan" => "silver",
               "team_id" => "a111"
             }
    end
  end

  describe "device_code/1,2" do
    test "starts the device flow" do
      stub_request(%{
        "device_code" => "dc_1",
        "user_code" => "ABCD-EFGH",
        "verification_uri" => "https://tenant.auth0.com/activate",
        "interval" => 5
      })

      assert {:ok, %{"user_code" => "ABCD-EFGH"}} =
               Authentication.device_code("a_client_id", %{
                 scope: "openid profile offline_access",
                 audience: "https://your-api/"
               })

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/oauth/device/code"
      assert request.content_type == "application/x-www-form-urlencoded"

      assert request.body == %{
               "client_id" => "a_client_id",
               "scope" => "openid profile offline_access",
               "audience" => "https://your-api/"
             }
    end

    # An empty form field is not the same as an absent one.
    test "omits scope and audience when not given" do
      stub_request(%{"device_code" => "dc_1"})

      assert {:ok, _} = Authentication.device_code("a_client_id")

      assert assert_receive_request().body == %{"client_id" => "a_client_id"}
    end
  end

  describe "pushed_authorization_request/1,2" do
    test "posts the authorization parameters and accepts a 201" do
      stub_json(201, %{"request_uri" => "urn:ietf:params:oauth:request_uri:x", "expires_in" => 90})

      assert {:ok, %{"request_uri" => "urn:ietf:params:oauth:request_uri:x"}} =
               Authentication.pushed_authorization_request("a_client_id", %{
                 client_secret: "a_secret",
                 response_type: "code",
                 redirect_uri: "https://app.example.com/callback"
               })

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/oauth/par"
      assert request.content_type == "application/x-www-form-urlencoded"

      assert request.body == %{
               "client_id" => "a_client_id",
               "client_secret" => "a_secret",
               "response_type" => "code",
               "redirect_uri" => "https://app.example.com/callback"
             }
    end
  end

  describe "global_token_revocation/3" do
    # The only /oauth/* endpoint this library calls that takes JSON rather than a
    # form-encoded body, and the only one authenticated by a caller-supplied token.
    test "sends a JSON body with the caller's bearer token" do
      stub_status(200)

      subject = %{format: "iss_sub", iss: "https://tenant.auth0.com/", sub: "auth0|abc123"}

      assert :ok =
               Authentication.global_token_revocation(
                 "Username-Password-Authentication",
                 subject,
                 "an_access_token"
               )

      request = assert_receive_request()
      assert request.method == "POST"

      assert request.path ==
               "/oauth/global-token-revocation/connection/Username-Password-Authentication"

      assert request.content_type == "application/json"

      assert request.body == %{
               "subject" => %{
                 "format" => "iss_sub",
                 "iss" => "https://tenant.auth0.com/",
                 "sub" => "auth0|abc123"
               }
             }

      assert {"authorization", "Bearer an_access_token"} in request.headers
    end
  end

  describe "authorization" do
    test "sends no authorization header when the caller supplies no token" do
      stub_request(%{"_id" => "1"})

      assert {:ok, _} = Authentication.change_password("a_client_id", "a@b.com", "a_connection")

      headers = assert_receive_request().headers
      refute List.keymember?(headers, "authorization", 0)
    end
  end

  describe "paths" do
    test "hang off the tenant root with no /api/v2 prefix" do
      stub_request(%{"_id" => "1"})

      assert {:ok, _} = Authentication.change_password("a_client_id", "a@b.com", "a_connection")

      refute assert_receive_request().path =~ "/api/v2"
    end
  end
end
