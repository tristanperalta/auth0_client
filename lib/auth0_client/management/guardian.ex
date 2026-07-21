defmodule Auth0Client.Management.Guardian do
  @moduledoc """
  A module representing Guardian, Auth0's multi-factor authentication, on Auth0.

  This is the tenant-wide configuration side of MFA — which factors exist, how they
  are delivered, and when they are required. The per-user side lives on
  `Auth0Client.Management.User`: `enrollments/1` reports what a user has enrolled and
  `delete_authenticators/1` resets it.

  ## update_ versus replace_

  Where Auth0 offers both verbs for a provider's configuration, `update_*` is the
  `PATCH` and merges into what is already there, while `replace_*` is the `PUT` and
  overwrites the whole configuration. Where Auth0 offers only `PUT` — the phone
  settings, the selected-provider endpoints and the policies — `update_*` is that
  `PUT`, since there is no second verb to distinguish it from.

  The `/guardian/factors/sms/*` endpoints are not wrapped. Auth0 documents them as
  deprecated and points at the `phone` equivalents below, which take the same
  payloads.

  https://auth0.com/docs/api/management/v2/guardian
  """

  use Auth0Client.Api, for: :mgmt
  @path "guardian"
  @factors "guardian/factors"
  @push "guardian/factors/push-notification/providers"

  @doc """
  Creates an enrollment ticket, the out-of-band way to get a user to enrol in MFA.

  `user_id` is required. `factor` may be one of `push-notification`, `phone`,
  `email`, `otp`, `webauthn-roaming` or `webauthn-platform`. Set `send_mail` to have
  Auth0 email the ticket, or read `ticket_url` from the response and deliver it
  yourself.

      iex> Auth0Client.Management.Guardian.create_enrollment_ticket(%{user_id: "auth0|123", send_mail: true})
  """
  def create_enrollment_ticket(body) when is_map(body) do
    do_post("#{@path}/enrollments/ticket", body)
  end

  @doc """
  Gets an enrollment

      iex> Auth0Client.Management.Guardian.enrollment("dev_abc123")
  """
  def enrollment(id) when is_binary(id), do: do_get("#{@path}/enrollments/#{id}", %{})

  @doc """
  Deletes an enrollment, so the user must enrol again

      iex> Auth0Client.Management.Guardian.delete_enrollment("dev_abc123")
  """
  def delete_enrollment(id) when is_binary(id), do: do_delete("#{@path}/enrollments/#{id}")

  @doc """
  Lists the available factors and whether each is enabled

      iex> Auth0Client.Management.Guardian.factors()
  """
  def factors, do: do_get(@factors, %{})

  @doc """
  Enables or disables a factor for the whole tenant.

  `name` is the factor — `sms`, `push-notification`, `otp`, `email`, `duo`,
  `webauthn-roaming`, `webauthn-platform` or `recovery-code`.

      iex> Auth0Client.Management.Guardian.update_factor("otp", %{enabled: true})
  """
  def update_factor(name, body) when is_binary(name) do
    do_put("#{@factors}/#{name}", body)
  end

  @doc """
  Gets the tenant's MFA policies

      iex> Auth0Client.Management.Guardian.policies()
  """
  def policies, do: do_get("#{@path}/policies", %{})

  @doc """
  Sets the tenant's MFA policies.

  The body is a bare list, not an object wrapping one. `["all-applications"]`
  always prompts; `["confidence-score"]` prompts adaptively; `[]` disables the
  policy.

      iex> Auth0Client.Management.Guardian.update_policies(["all-applications"])
      iex> Auth0Client.Management.Guardian.update_policies([])
  """
  def update_policies(policies) when is_list(policies) do
    do_put("#{@path}/policies", policies)
  end

  @doc """
  Gets the message types enabled for the phone factor

      iex> Auth0Client.Management.Guardian.phone_message_types()
  """
  def phone_message_types, do: do_get("#{@factors}/phone/message-types", %{})

  @doc """
  Sets the message types for the phone factor — `sms`, `voice`, or both

      iex> Auth0Client.Management.Guardian.update_phone_message_types(%{message_types: ["sms", "voice"]})
  """
  def update_phone_message_types(body) when is_map(body) do
    do_put("#{@factors}/phone/message-types", body)
  end

  @doc """
  Gets the Twilio configuration for the phone factor

      iex> Auth0Client.Management.Guardian.phone_twilio()
  """
  def phone_twilio, do: do_get("#{@factors}/phone/providers/twilio", %{})

  @doc """
  Sets the Twilio configuration for the phone factor

      iex> Auth0Client.Management.Guardian.update_phone_twilio(%{sid: "AC...", auth_token: "...", from: "+15551234567"})
  """
  def update_phone_twilio(body) when is_map(body) do
    do_put("#{@factors}/phone/providers/twilio", body)
  end

  @doc """
  Gets which provider delivers the phone factor

      iex> Auth0Client.Management.Guardian.phone_provider()
  """
  def phone_provider, do: do_get("#{@factors}/phone/selected-provider", %{})

  @doc """
  Chooses which provider delivers the phone factor — `auth0`, `twilio` or
  `phone-message-hook`

      iex> Auth0Client.Management.Guardian.update_phone_provider(%{provider: "twilio"})
  """
  def update_phone_provider(body) when is_map(body) do
    do_put("#{@factors}/phone/selected-provider", body)
  end

  @doc """
  Gets the enrollment and verification message templates for the phone factor

      iex> Auth0Client.Management.Guardian.phone_templates()
  """
  def phone_templates, do: do_get("#{@factors}/phone/templates", %{})

  @doc """
  Customises the enrollment and verification messages for the phone factor

      iex> Auth0Client.Management.Guardian.update_phone_templates(%{enrollment_message: "Your code is @@password@@"})
  """
  def update_phone_templates(body) when is_map(body) do
    do_put("#{@factors}/phone/templates", body)
  end

  @doc """
  Gets which provider delivers push notifications

      iex> Auth0Client.Management.Guardian.push_provider()
  """
  def push_provider, do: do_get("#{@factors}/push-notification/selected-provider", %{})

  @doc """
  Chooses which provider delivers push notifications — `guardian`, `sns` or `direct`

      iex> Auth0Client.Management.Guardian.update_push_provider(%{provider: "direct"})
  """
  def update_push_provider(body) when is_map(body) do
    do_put("#{@factors}/push-notification/selected-provider", body)
  end

  @doc """
  Gets the APNs push configuration

      iex> Auth0Client.Management.Guardian.apns()
  """
  def apns, do: do_get("#{@push}/apns", %{})

  @doc """
  Merges into the APNs push configuration

      iex> Auth0Client.Management.Guardian.update_apns(%{sandbox: true})
  """
  def update_apns(body) when is_map(body), do: do_patch("#{@push}/apns", body)

  @doc """
  Replaces the whole APNs push configuration

      iex> Auth0Client.Management.Guardian.replace_apns(%{bundle_id: "com.example.app", p12: "...", sandbox: false})
  """
  def replace_apns(body) when is_map(body), do: do_put("#{@push}/apns", body)

  @doc """
  Gets the Amazon SNS push configuration

      iex> Auth0Client.Management.Guardian.sns()
  """
  def sns, do: do_get("#{@push}/sns", %{})

  @doc """
  Merges into the Amazon SNS push configuration

      iex> Auth0Client.Management.Guardian.update_sns(%{aws_region: "us-east-1"})
  """
  def update_sns(body) when is_map(body), do: do_patch("#{@push}/sns", body)

  @doc """
  Replaces the whole Amazon SNS push configuration

      iex> Auth0Client.Management.Guardian.replace_sns(%{aws_access_key_id: "...", aws_region: "us-east-1"})
  """
  def replace_sns(body) when is_map(body), do: do_put("#{@push}/sns", body)

  @doc """
  Merges into the FCM push configuration.

  Auth0 exposes no way to read the FCM configuration back — only `PATCH` and `PUT`.
  That asymmetry with APNs and SNS is Auth0's, not an omission here.

      iex> Auth0Client.Management.Guardian.update_fcm(%{server_key: "..."})
  """
  def update_fcm(body) when is_map(body), do: do_patch("#{@push}/fcm", body)

  @doc """
  Replaces the whole FCM push configuration. Write-only, as with `update_fcm/1`.

      iex> Auth0Client.Management.Guardian.replace_fcm(%{server_key: "..."})
  """
  def replace_fcm(body) when is_map(body), do: do_put("#{@push}/fcm", body)

  @doc """
  Merges into the FCM v1 push configuration. Write-only, as with `update_fcm/1`.

      iex> Auth0Client.Management.Guardian.update_fcmv1(%{server_credentials: "..."})
  """
  def update_fcmv1(body) when is_map(body), do: do_patch("#{@push}/fcmv1", body)

  @doc """
  Replaces the whole FCM v1 push configuration. Write-only, as with `update_fcm/1`.

      iex> Auth0Client.Management.Guardian.replace_fcmv1(%{server_credentials: "..."})
  """
  def replace_fcmv1(body) when is_map(body), do: do_put("#{@push}/fcmv1", body)

  @doc """
  Gets the Duo configuration

      iex> Auth0Client.Management.Guardian.duo_settings()
  """
  def duo_settings, do: do_get("#{@factors}/duo/settings", %{})

  @doc """
  Merges into the Duo configuration

      iex> Auth0Client.Management.Guardian.update_duo_settings(%{hostname: "api-abc.duosecurity.com"})
  """
  def update_duo_settings(body) when is_map(body) do
    do_patch("#{@factors}/duo/settings", body)
  end

  @doc """
  Replaces the whole Duo configuration

      iex> Auth0Client.Management.Guardian.replace_duo_settings(%{ikey: "...", skey: "...", hostname: "api-abc.duosecurity.com"})
  """
  def replace_duo_settings(body) when is_map(body) do
    do_put("#{@factors}/duo/settings", body)
  end
end
