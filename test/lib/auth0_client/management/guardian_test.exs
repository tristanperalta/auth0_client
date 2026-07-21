defmodule Auth0Client.Management.GuardianTest do
  use ExUnit.Case, async: true
  use Auth0Client.ReqCase

  alias Auth0Client.Management.Guardian

  defp empty(status), do: fn conn -> Plug.Conn.send_resp(conn, status, "") end

  describe "enrollments" do
    test "create_enrollment_ticket/1 posts the ticket request" do
      stub_request(%{"ticket_url" => "https://tenant.auth0.com/guardian/enroll?ticket=abc"})

      assert {:ok, %{"ticket_url" => _}} =
               Guardian.create_enrollment_ticket(%{user_id: "auth0|123", send_mail: true})

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/guardian/enrollments/ticket"
      assert request.body == %{"user_id" => "auth0|123", "send_mail" => true}
    end

    test "enrollment/1 gets one" do
      stub_request(%{"id" => "dev_1", "status" => "confirmed"})

      assert {:ok, %{"id" => "dev_1"}} = Guardian.enrollment("dev_1")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/guardian/enrollments/dev_1"
    end

    test "delete_enrollment/1 removes it" do
      stub_request(empty(204))

      assert :ok = Guardian.delete_enrollment("dev_1")

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/guardian/enrollments/dev_1"
    end
  end

  describe "factors" do
    test "factors/0 lists them" do
      stub_request([%{"name" => "otp", "enabled" => true}])

      assert {:ok, [%{"name" => "otp"}]} = Guardian.factors()

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/guardian/factors"
    end

    test "update_factor/2 enables one by name" do
      stub_request(%{"enabled" => true})

      assert {:ok, %{"enabled" => true}} = Guardian.update_factor("otp", %{enabled: true})

      request = assert_receive_request()
      assert request.method == "PUT"
      assert request.path == "/api/v2/guardian/factors/otp"
      assert request.body == %{"enabled" => true}
    end
  end

  describe "policies" do
    test "policies/0 gets them" do
      stub_request(["all-applications"])

      assert {:ok, ["all-applications"]} = Guardian.policies()

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/guardian/policies"
    end

    # The body is a bare array, not an object wrapping one.
    test "update_policies/1 puts a bare array" do
      stub_request(["all-applications"])

      assert {:ok, _} = Guardian.update_policies(["all-applications"])

      request = assert_receive_request()
      assert request.method == "PUT"
      assert request.path == "/api/v2/guardian/policies"
      assert request.body == ["all-applications"]
      assert is_list(request.body)
    end

    test "an empty list disables the policy" do
      stub_request([])

      assert {:ok, _} = Guardian.update_policies([])

      assert assert_receive_request().body == []
    end
  end

  describe "phone factor" do
    test "phone_message_types/0 and update_phone_message_types/1" do
      stub_request(%{"message_types" => ["sms"]})
      Guardian.phone_message_types()

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/guardian/factors/phone/message-types"

      stub_request(%{"message_types" => ["sms", "voice"]})
      Guardian.update_phone_message_types(%{message_types: ["sms", "voice"]})

      request = assert_receive_request()
      assert request.method == "PUT"
      assert request.path == "/api/v2/guardian/factors/phone/message-types"
      assert request.body == %{"message_types" => ["sms", "voice"]}
    end

    test "phone_twilio/0 and update_phone_twilio/1" do
      stub_request(%{"sid" => "AC1"})
      Guardian.phone_twilio()

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/guardian/factors/phone/providers/twilio"

      stub_request(%{"sid" => "AC1"})
      Guardian.update_phone_twilio(%{sid: "AC1", auth_token: "tok"})

      request = assert_receive_request()
      assert request.method == "PUT"
      assert request.path == "/api/v2/guardian/factors/phone/providers/twilio"
      assert request.body == %{"sid" => "AC1", "auth_token" => "tok"}
    end

    test "phone_provider/0 and update_phone_provider/1" do
      stub_request(%{"provider" => "auth0"})
      Guardian.phone_provider()

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/guardian/factors/phone/selected-provider"

      stub_request(%{"provider" => "twilio"})
      Guardian.update_phone_provider(%{provider: "twilio"})

      request = assert_receive_request()
      assert request.method == "PUT"
      assert request.path == "/api/v2/guardian/factors/phone/selected-provider"
      assert request.body == %{"provider" => "twilio"}
    end

    test "phone_templates/0 and update_phone_templates/1" do
      stub_request(%{"enrollment_message" => "x"})
      Guardian.phone_templates()

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/guardian/factors/phone/templates"

      stub_request(%{"enrollment_message" => "Your code is @@password@@"})
      Guardian.update_phone_templates(%{enrollment_message: "Your code is @@password@@"})

      request = assert_receive_request()
      assert request.method == "PUT"
      assert request.path == "/api/v2/guardian/factors/phone/templates"
    end
  end

  describe "push notification provider selection" do
    test "push_provider/0 and update_push_provider/1" do
      stub_request(%{"provider" => "guardian"})
      Guardian.push_provider()

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/guardian/factors/push-notification/selected-provider"

      stub_request(%{"provider" => "direct"})
      Guardian.update_push_provider(%{provider: "direct"})

      request = assert_receive_request()
      assert request.method == "PUT"
      assert request.path == "/api/v2/guardian/factors/push-notification/selected-provider"
      assert request.body == %{"provider" => "direct"}
    end
  end

  describe "APNs" do
    test "apns/0 reads the configuration" do
      stub_request(%{"bundle_id" => "com.example.app"})

      assert {:ok, %{"bundle_id" => _}} = Guardian.apns()

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/guardian/factors/push-notification/providers/apns"
    end

    test "update_apns/1 merges with PATCH" do
      stub_request(%{})
      Guardian.update_apns(%{sandbox: true})

      request = assert_receive_request()
      assert request.method == "PATCH"
      assert request.path == "/api/v2/guardian/factors/push-notification/providers/apns"
      assert request.body == %{"sandbox" => true}
    end

    test "replace_apns/1 overwrites with PUT" do
      stub_request(%{})
      Guardian.replace_apns(%{bundle_id: "com.example.app", sandbox: false})

      request = assert_receive_request()
      assert request.method == "PUT"
      assert request.path == "/api/v2/guardian/factors/push-notification/providers/apns"
    end
  end

  describe "SNS" do
    test "sns/0 reads the configuration" do
      stub_request(%{"aws_region" => "us-east-1"})

      assert {:ok, _} = Guardian.sns()

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/guardian/factors/push-notification/providers/sns"
    end

    test "update_sns/1 merges with PATCH" do
      stub_request(%{})
      Guardian.update_sns(%{aws_region: "eu-west-1"})

      request = assert_receive_request()
      assert request.method == "PATCH"
      assert request.path == "/api/v2/guardian/factors/push-notification/providers/sns"
    end

    test "replace_sns/1 overwrites with PUT" do
      stub_request(%{})
      Guardian.replace_sns(%{aws_region: "eu-west-1"})

      request = assert_receive_request()
      assert request.method == "PUT"
      assert request.path == "/api/v2/guardian/factors/push-notification/providers/sns"
    end
  end

  # Auth0 exposes no GET for either FCM provider — write-only by their design.
  describe "FCM and FCM v1" do
    test "update_fcm/1 merges with PATCH" do
      stub_request(%{})
      Guardian.update_fcm(%{server_key: "key"})

      request = assert_receive_request()
      assert request.method == "PATCH"
      assert request.path == "/api/v2/guardian/factors/push-notification/providers/fcm"
      assert request.body == %{"server_key" => "key"}
    end

    test "replace_fcm/1 overwrites with PUT" do
      stub_request(%{})
      Guardian.replace_fcm(%{server_key: "key"})

      request = assert_receive_request()
      assert request.method == "PUT"
      assert request.path == "/api/v2/guardian/factors/push-notification/providers/fcm"
    end

    test "update_fcmv1/1 merges with PATCH" do
      stub_request(%{})
      Guardian.update_fcmv1(%{server_credentials: "creds"})

      request = assert_receive_request()
      assert request.method == "PATCH"
      assert request.path == "/api/v2/guardian/factors/push-notification/providers/fcmv1"
    end

    test "replace_fcmv1/1 overwrites with PUT" do
      stub_request(%{})
      Guardian.replace_fcmv1(%{server_credentials: "creds"})

      request = assert_receive_request()
      assert request.method == "PUT"
      assert request.path == "/api/v2/guardian/factors/push-notification/providers/fcmv1"
    end
  end

  describe "Duo" do
    test "duo_settings/0 reads the configuration" do
      stub_request(%{"hostname" => "api-abc.duosecurity.com"})

      assert {:ok, _} = Guardian.duo_settings()

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/guardian/factors/duo/settings"
    end

    test "update_duo_settings/1 merges with PATCH" do
      stub_request(%{})
      Guardian.update_duo_settings(%{hostname: "api-abc.duosecurity.com"})

      request = assert_receive_request()
      assert request.method == "PATCH"
      assert request.path == "/api/v2/guardian/factors/duo/settings"
    end

    test "replace_duo_settings/1 overwrites with PUT" do
      stub_request(%{})
      Guardian.replace_duo_settings(%{ikey: "i", skey: "s"})

      request = assert_receive_request()
      assert request.method == "PUT"
      assert request.path == "/api/v2/guardian/factors/duo/settings"
    end
  end

  # update_ is the merging PATCH and replace_ is the overwriting PUT. Transposing
  # them would silently wipe a provider's configuration.
  describe "update_ and replace_ never use the same verb" do
    test "each pair is PATCH then PUT" do
      pairs = [
        {&Guardian.update_apns/1, &Guardian.replace_apns/1},
        {&Guardian.update_sns/1, &Guardian.replace_sns/1},
        {&Guardian.update_fcm/1, &Guardian.replace_fcm/1},
        {&Guardian.update_fcmv1/1, &Guardian.replace_fcmv1/1},
        {&Guardian.update_duo_settings/1, &Guardian.replace_duo_settings/1}
      ]

      for {update, replace} <- pairs do
        stub_request(%{})
        update.(%{})
        assert assert_receive_request().method == "PATCH"

        stub_request(%{})
        replace.(%{})
        assert assert_receive_request().method == "PUT"
      end
    end
  end

  describe "authorization" do
    test "sends the management token" do
      stub_request([])
      Guardian.factors()

      assert {"authorization", "Bearer TESTTOKEN"} in assert_receive_request().headers
    end
  end
end
