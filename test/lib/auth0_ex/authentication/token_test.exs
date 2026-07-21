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

  describe "client_credentials/4 options" do
    test "sends an organization for an org-scoped token" do
      stub_request(%{"access_token" => "a_token"})

      Token.client_credentials("an_id", "a_secret", "an_audience", %{organization: "org_abc"})

      assert assert_receive_request().body["organization"] == "org_abc"
    end

    # Private Key JWT: there is no shared secret, so nil is passed and pruned.
    test "omits client_secret when it is nil, and sends the assertion instead" do
      stub_request(%{"access_token" => "a_token"})

      Token.client_credentials("an_id", nil, "an_audience", %{
        client_assertion: "signed.jwt.here",
        client_assertion_type: "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
      })

      body = assert_receive_request().body
      refute Map.has_key?(body, "client_secret")
      assert body["client_assertion"] == "signed.jwt.here"

      assert body["client_assertion_type"] ==
               "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
    end

    test "sends no assertion keys when none are given" do
      stub_request(%{"access_token" => "a_token"})
      Token.client_credentials("an_id", "a_secret", "an_audience")

      body = assert_receive_request().body
      refute Map.has_key?(body, "client_assertion")
      refute Map.has_key?(body, "organization")
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

  describe "device/2,3" do
    test "sends the device_code grant type, form-encoded" do
      stub_request(%{"access_token" => "a_token"})

      assert {:ok, %{"access_token" => "a_token"}} = Token.device("an_id", "a_device_code")

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/oauth/token"
      assert request.content_type == "application/x-www-form-urlencoded"

      assert request.body == %{
               "client_id" => "an_id",
               "device_code" => "a_device_code",
               "grant_type" => "urn:ietf:params:oauth:grant-type:device_code"
             }
    end

    test "posts a client_secret given in opts" do
      stub_request(%{"access_token" => "a_token"})
      Token.device("an_id", "a_device_code", %{client_secret: "a_secret"})

      assert assert_receive_request().body["client_secret"] == "a_secret"
    end

    # authorization_pending is the normal state while the user is still approving, not
    # a failure. It arrives as an error like any other, so a caller has to read the
    # code out of the body rather than bailing on the first {:error, _}.
    test "authorization_pending arrives as an error carrying a readable code" do
      stub_request(fn conn ->
        conn
        |> Plug.Conn.put_status(403)
        |> Req.Test.json(%{
          "error" => "authorization_pending",
          "error_description" => "User has yet to authorize device code."
        })
      end)

      assert {:error, %Auth0Ex.Error{status: 403, body: body}} =
               Token.device("an_id", "a_device_code")

      assert body["error"] == "authorization_pending"
    end
  end

  describe "native_social/3,4" do
    test "sends the token-exchange grant type with the subject token" do
      stub_request(%{"access_token" => "a_token"})

      assert {:ok, _} =
               Token.native_social(
                 "an_id",
                 "an_apple_token",
                 "http://auth0.com/oauth/token-type/apple-authz-code"
               )

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/oauth/token"

      assert request.body == %{
               "client_id" => "an_id",
               "subject_token" => "an_apple_token",
               "subject_token_type" => "http://auth0.com/oauth/token-type/apple-authz-code",
               "grant_type" => "urn:ietf:params:oauth:grant-type:token-exchange"
             }
    end

    # A form-encoded body has no representation for a nested object, and
    # URI.encode_query/1 raises on one. Auth0 takes user_profile as JSON in a single
    # field, so without the encoding this call would not send at all.
    test "JSON-encodes user_profile into one field, leaving flat fields alone" do
      stub_request(%{"access_token" => "a_token"})

      assert {:ok, _} =
               Token.native_social("an_id", "a_token", "a_type", %{
                 scope: "openid profile",
                 user_profile: %{name: %{firstName: "John", lastName: "Smith"}}
               })

      body = assert_receive_request().body
      assert body["scope"] == "openid profile"

      assert Jason.decode!(body["user_profile"]) == %{
               "name" => %{"firstName" => "John", "lastName" => "Smith"}
             }
    end

    test "passes a user_profile that is already a string through unchanged" do
      stub_request(%{"access_token" => "a_token"})
      Token.native_social("an_id", "a_token", "a_type", %{user_profile: ~s({"name":{}})})

      assert assert_receive_request().body["user_profile"] == ~s({"name":{}})
    end

    test "forwards the end user's ip like the password grant does" do
      stub_request(%{"access_token" => "a_token"})
      Token.native_social("an_id", "a_token", "a_type", %{forwarded_for: "203.0.113.5"})

      assert {"auth0-forwarded-for", "203.0.113.5"} in assert_receive_request().headers
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
