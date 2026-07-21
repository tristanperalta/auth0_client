defmodule Auth0Ex.Authentication.TokenTest do
  use ExUnit.Case, async: true
  use Auth0Ex.ReqCase

  alias Auth0Ex.Authentication.Mfa
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

  describe "refresh/2,3" do
    test "posts the refresh_token grant" do
      stub_request(%{"access_token" => "a_new_token"})

      assert {:ok, %{"access_token" => "a_new_token"}} = Token.refresh("an_id", "a_refresh_token")

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/oauth/token"

      assert request.body == %{
               "client_id" => "an_id",
               "refresh_token" => "a_refresh_token",
               "grant_type" => "refresh_token"
             }
    end

    test "sends no client_secret for a public client" do
      stub_request(%{"access_token" => "a_new_token"})
      Token.refresh("an_id", "a_refresh_token")

      refute Map.has_key?(assert_receive_request().body, "client_secret")
    end

    test "posts a client_secret and scope given in opts" do
      stub_request(%{"access_token" => "a_new_token"})

      Token.refresh("an_id", "a_refresh_token", %{
        client_secret: "a_secret",
        scope: "openid profile"
      })

      body = assert_receive_request().body
      assert body["client_secret"] == "a_secret"
      assert body["scope"] == "openid profile"
    end
  end

  describe "password/3,4" do
    test "posts the password grant" do
      stub_request(%{"access_token" => "a_token"})

      assert {:ok, %{"access_token" => "a_token"}} =
               Token.password("an_id", "user@example.com", "a_password")

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/oauth/token"

      assert request.body == %{
               "client_id" => "an_id",
               "username" => "user@example.com",
               "password" => "a_password",
               "grant_type" => "password"
             }
    end

    test "a realm switches to the password-realm grant" do
      stub_request(%{"access_token" => "a_token"})

      Token.password("an_id", "user@example.com", "a_password", %{
        realm: "Username-Password-Authentication"
      })

      body = assert_receive_request().body
      assert body["grant_type"] == "http://auth0.com/oauth/grant-type/password-realm"
      assert body["realm"] == "Username-Password-Authentication"
    end

    test "posts audience, scope and client_secret from opts" do
      stub_request(%{"access_token" => "a_token"})

      Token.password("an_id", "user@example.com", "a_password", %{
        audience: "https://api.example.com",
        scope: "openid",
        client_secret: "a_secret"
      })

      body = assert_receive_request().body
      assert body["audience"] == "https://api.example.com"
      assert body["scope"] == "openid"
      assert body["client_secret"] == "a_secret"
    end

    test "forwards the end user's ip for brute-force protection" do
      stub_request(%{"access_token" => "a_token"})

      Token.password("an_id", "user@example.com", "a_password", %{forwarded_for: "198.51.100.7"})

      request = assert_receive_request()
      assert {"auth0-forwarded-for", "198.51.100.7"} in request.headers
      refute Map.has_key?(request.body, "forwarded_for")
    end

    test "sends no forwarding header when no ip is given" do
      stub_request(%{"access_token" => "a_token"})
      Token.password("an_id", "user@example.com", "a_password")

      refute List.keymember?(assert_receive_request().headers, "auth0-forwarded-for", 0)
    end
  end

  describe "revoke/2,3" do
    test "posts to the revoke endpoint and normalises the empty 200 body to :ok" do
      stub_request(fn conn -> Plug.Conn.send_resp(conn, 200, "") end)

      assert :ok = Token.revoke("an_id", "a_refresh_token")

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/oauth/revoke"
      assert request.body == %{"client_id" => "an_id", "token" => "a_refresh_token"}
    end

    test "posts a client_secret given in opts" do
      stub_request(fn conn -> Plug.Conn.send_resp(conn, 200, "") end)

      assert :ok = Token.revoke("an_id", "a_refresh_token", %{client_secret: "a_secret"})

      assert assert_receive_request().body["client_secret"] == "a_secret"
    end

    test "surfaces a rejection as an error" do
      stub_request(fn conn ->
        conn |> Plug.Conn.put_status(400) |> Req.Test.json(%{"error" => "invalid_request"})
      end)

      assert {:error, %Auth0Ex.Error{reason: :bad_request, status: 400}} =
               Token.revoke("an_id", "a_refresh_token")
    end
  end

  describe "MFA verify grants" do
    test "verify_otp/3 sends the mfa-otp grant" do
      stub_request(%{"access_token" => "a_token"})

      assert {:ok, %{"access_token" => "a_token"}} =
               Token.verify_otp("an_id", "mfa_tok", "123456")

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/oauth/token"

      assert request.body == %{
               "client_id" => "an_id",
               "mfa_token" => "mfa_tok",
               "otp" => "123456",
               "grant_type" => "http://auth0.com/oauth/grant-type/mfa-otp"
             }
    end

    test "verify_oob/3 sends the mfa-oob grant and omits binding_code by default" do
      stub_request(%{"access_token" => "a_token"})

      assert {:ok, _} = Token.verify_oob("an_id", "mfa_tok", "oob_code")

      request = assert_receive_request()

      assert request.body == %{
               "client_id" => "an_id",
               "mfa_token" => "mfa_tok",
               "oob_code" => "oob_code",
               "grant_type" => "http://auth0.com/oauth/grant-type/mfa-oob"
             }

      refute Map.has_key?(request.body, "binding_code")
    end

    test "verify_oob/4 sends binding_code when the challenge demanded a prompt" do
      stub_request(%{"access_token" => "a_token"})

      Token.verify_oob("an_id", "mfa_tok", "oob_code", %{binding_code: "1234"})

      assert assert_receive_request().body["binding_code"] == "1234"
    end

    test "verify_recovery_code/3 sends the mfa-recovery-code grant" do
      stub_request(%{"access_token" => "a_token", "recovery_code" => "NEWCODE"})

      assert {:ok, %{"recovery_code" => "NEWCODE"}} =
               Token.verify_recovery_code("an_id", "mfa_tok", "OLDCODE")

      request = assert_receive_request()

      assert request.body == %{
               "client_id" => "an_id",
               "mfa_token" => "mfa_tok",
               "recovery_code" => "OLDCODE",
               "grant_type" => "http://auth0.com/oauth/grant-type/mfa-recovery-code"
             }
    end

    # Three grants that differ only in their grant_type and one field. A
    # copy-paste between them would be invisible in review.
    test "the three grants send three distinct grant types" do
      calls = [
        fn -> Token.verify_otp("an_id", "mfa_tok", "123456") end,
        fn -> Token.verify_oob("an_id", "mfa_tok", "oob_code") end,
        fn -> Token.verify_recovery_code("an_id", "mfa_tok", "CODE") end
      ]

      grant_types =
        for call <- calls do
          stub_request(%{"access_token" => "a_token"})
          call.()
          assert_receive_request().body["grant_type"]
        end

      assert grant_types == [
               "http://auth0.com/oauth/grant-type/mfa-otp",
               "http://auth0.com/oauth/grant-type/mfa-oob",
               "http://auth0.com/oauth/grant-type/mfa-recovery-code"
             ]

      assert Enum.uniq(grant_types) == grant_types
    end

    test "each accepts a client_secret for a confidential client" do
      stub_request(%{"access_token" => "a_token"})
      Token.verify_otp("an_id", "mfa_tok", "123456", %{client_secret: "a_secret"})

      assert assert_receive_request().body["client_secret"] == "a_secret"
    end
  end

  describe "passwordless/4,5" do
    test "sends the passwordless otp grant" do
      stub_request(%{"access_token" => "a_token"})

      assert {:ok, _} = Token.passwordless("an_id", "user@example.com", "123456", "email")

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/oauth/token"

      assert request.body == %{
               "client_id" => "an_id",
               "username" => "user@example.com",
               "otp" => "123456",
               "realm" => "email",
               "grant_type" => "http://auth0.com/oauth/grant-type/passwordless/otp"
             }
    end

    test "the username is a phone number when the realm is sms" do
      stub_request(%{"access_token" => "a_token"})

      Token.passwordless("an_id", "+15551234567", "123456", "sms")

      body = assert_receive_request().body
      assert body["username"] == "+15551234567"
      assert body["realm"] == "sms"
    end
  end

  # The individual calls above are each correct; this is the order they go in.
  describe "the MFA login flow end to end" do
    test "password grant reports mfa_required, then challenge, then verify" do
      stub_request(fn conn ->
        conn
        |> Plug.Conn.put_status(403)
        |> Req.Test.json(%{"error" => "mfa_required", "mfa_token" => "mfa_tok"})
      end)

      assert {:error, %Auth0Ex.Error{status: 403, body: body}} =
               Token.password("an_id", "user@example.com", "pwd")

      assert body["error"] == "mfa_required"
      mfa_token = body["mfa_token"]
      assert_receive_request()

      stub_request(%{"challenge_type" => "otp"})

      assert {:ok, %{"challenge_type" => "otp"}} =
               Mfa.challenge(%{mfa_token: mfa_token, client_id: "an_id"})

      assert assert_receive_request().path == "/mfa/challenge"

      stub_request(%{"access_token" => "a_token"})

      assert {:ok, %{"access_token" => "a_token"}} =
               Token.verify_otp("an_id", mfa_token, "123456")

      assert assert_receive_request().body["mfa_token"] == "mfa_tok"
    end
  end

  describe "encoding" do
    test "token requests are form-encoded, as RFC 6749 and Auth0 specify" do
      stub_request(%{"access_token" => "a_token"})
      Token.client_credentials("an_id", "a_secret", "an_audience")

      assert assert_receive_request().content_type == "application/x-www-form-urlencoded"
    end

    test "every grant uses the same encoding" do
      for call <- [
            fn -> Token.auth_code("an_id", "a_secret", "a_code") end,
            fn -> Token.auth_code_pkce("an_id", "a_code", "a_verifier") end,
            fn -> Token.refresh("an_id", "a_refresh_token") end,
            fn -> Token.password("an_id", "a_user", "a_password") end
          ] do
        stub_request(%{"access_token" => "a_token"})
        call.()

        assert assert_receive_request().content_type == "application/x-www-form-urlencoded"
      end
    end

    test "revoke is form-encoded too" do
      stub_request(fn conn -> Plug.Conn.send_resp(conn, 200, "") end)
      Token.revoke("an_id", "a_refresh_token")

      assert assert_receive_request().content_type == "application/x-www-form-urlencoded"
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
