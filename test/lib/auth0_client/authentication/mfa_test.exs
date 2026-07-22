defmodule Auth0Client.Authentication.MfaTest do
  use ExUnit.Case, async: true
  use Auth0Client.ReqCase

  alias Auth0Client.Authentication.Mfa

  @mfa_token "mfa_tok_abc"
  @access_token "at_abc"

  defp authorization(request), do: List.keyfind(request.headers, "authorization", 0)

  describe "challenge/1" do
    test "posts the challenge request" do
      stub_request(%{"challenge_type" => "otp"})

      assert {:ok, %{"challenge_type" => "otp"}} =
               Mfa.challenge(%{mfa_token: @mfa_token, client_id: "a_client_id"})

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/mfa/challenge"
      assert request.body == %{"mfa_token" => @mfa_token, "client_id" => "a_client_id"}
    end

    test "passes through challenge_type and authenticator_id" do
      stub_request(%{})

      Mfa.challenge(%{
        mfa_token: @mfa_token,
        client_id: "a_client_id",
        challenge_type: "oob otp",
        authenticator_id: "recovery-code|dev_1"
      })

      body = assert_receive_request().body
      assert body["challenge_type"] == "oob otp"
      assert body["authenticator_id"] == "recovery-code|dev_1"
    end

    test "is sent as JSON" do
      stub_request(%{})
      Mfa.challenge(%{mfa_token: @mfa_token, client_id: "a_client_id"})

      assert assert_receive_request().content_type == "application/json"
    end
  end

  describe "associate/2" do
    test "posts the enrolment with the caller's bearer token" do
      stub_request(%{"authenticator_type" => "otp", "recovery_codes" => ["ABC"]})

      assert {:ok, %{"recovery_codes" => _}} =
               Mfa.associate(@access_token, %{authenticator_types: ["otp"]})

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/mfa/associate"
      assert request.body == %{"authenticator_types" => ["otp"]}
      assert authorization(request) == {"authorization", "Bearer #{@access_token}"}
    end

    test "accepts an mfa_token in place of an access token, for first enrolment" do
      stub_request(%{})

      Mfa.associate(@mfa_token, %{authenticator_types: ["oob"], oob_channels: ["sms"]})

      assert authorization(assert_receive_request()) ==
               {"authorization", "Bearer #{@mfa_token}"}
    end
  end

  describe "authenticators/1" do
    test "lists them with the caller's bearer token" do
      stub_request([%{"id" => "totp|dev_1", "active" => true}])

      assert {:ok, [%{"id" => "totp|dev_1"}]} = Mfa.authenticators(@access_token)

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/mfa/authenticators"
      assert authorization(request) == {"authorization", "Bearer #{@access_token}"}
    end
  end

  describe "delete_authenticator/2" do
    test "deletes by id with the caller's bearer token" do
      stub_status(204)

      assert :ok = Mfa.delete_authenticator(@access_token, "totp|dev_1")

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/mfa/authenticators/totp|dev_1"
      assert authorization(request) == {"authorization", "Bearer #{@access_token}"}
    end
  end

  # These are Authentication API calls made on behalf of an end user. The
  # management token has no business here, and sending it would be a real defect.
  describe "credentials" do
    test "no call carries the management token" do
      calls = [
        fn -> Mfa.challenge(%{mfa_token: @mfa_token, client_id: "a_client_id"}) end,
        fn -> Mfa.associate(@access_token, %{authenticator_types: ["otp"]}) end,
        fn -> Mfa.authenticators(@access_token) end,
        fn -> Mfa.delete_authenticator(@access_token, "totp|dev_1") end
      ]

      for call <- calls do
        stub_request(%{})
        call.()

        headers = assert_receive_request().headers
        refute {"authorization", "Bearer TESTTOKEN"} in headers
      end
    end

    test "challenge/1 sends no authorization header at all" do
      stub_request(%{})
      Mfa.challenge(%{mfa_token: @mfa_token, client_id: "a_client_id"})

      assert authorization(assert_receive_request()) == nil
    end

    test "an extra authorization replaces rather than duplicates" do
      stub_request(%{})
      Mfa.authenticators(@access_token)

      headers = assert_receive_request().headers
      assert Enum.count(headers, &match?({"authorization", _}, &1)) == 1
    end
  end

  describe "paths" do
    test "hang off the tenant root with no /api/v2 prefix" do
      stub_request(%{})
      Mfa.challenge(%{mfa_token: @mfa_token, client_id: "a_client_id"})

      refute assert_receive_request().path =~ "/api/v2"
    end
  end
end
