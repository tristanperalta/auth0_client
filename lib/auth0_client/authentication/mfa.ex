defmodule Auth0Client.Authentication.Mfa do
  @moduledoc """
  The end-user side of multi-factor authentication.

  This is where an MFA login is completed and where users enrol their own
  authenticators. The tenant-wide configuration — which factors exist, how they are
  delivered — is `Auth0Client.Management.Guardian`.

  A typical MFA login runs:

      # 1. the password grant reports that MFA is needed, as a 403 error
      {:error, %Auth0Client.Error{body: %{"mfa_token" => mfa_token}}} =
        Auth0Client.Authentication.Token.password(client_id, username, password)

      # 2. ask Auth0 to challenge the user
      {:ok, _} = Auth0Client.Authentication.Mfa.challenge(%{mfa_token: mfa_token, client_id: client_id})

      # 3. exchange the code the user gives you for tokens
      {:ok, tokens} = Auth0Client.Authentication.Token.verify_otp(client_id, mfa_token, otp)

  Tokens here belong to the end user, not the tenant, so they are passed per call
  rather than read from config. Nothing in this module sends the management token.

  https://auth0.com/docs/api/authentication/multi-factor-authentication
  """

  use Auth0Client.Api
  @path "mfa"

  @doc """
  Asks Auth0 to challenge the user for a second factor.

  `mfa_token` and `client_id` are required. `challenge_type` narrows what is
  acceptable — `"otp"`, `"oob"`, or both space-separated — and `authenticator_id`
  picks a specific enrolled authenticator.

  An out-of-band challenge returns an `oob_code` to pass to
  `Auth0Client.Authentication.Token.verify_oob/4`, and sometimes a
  `binding_method` of `"prompt"`, which means you must also collect a
  `binding_code` from the user.

      iex> Auth0Client.Authentication.Mfa.challenge(%{mfa_token: "mfa_tok", client_id: "a_client_id"})
      iex> Auth0Client.Authentication.Mfa.challenge(%{mfa_token: "mfa_tok", client_id: "a_client_id", challenge_type: "otp"})
  """
  def challenge(body) when is_map(body), do: do_post("#{@path}/challenge", body)

  @doc """
  Enrols a new authenticator for the user.

  `token` is either an access token with the `enroll` scope and audience
  `https://{your_domain}/mfa/`, or — when the user has no active authenticator yet
  — the `mfa_token` from an `mfa_required` error. That substitution is what makes
  first-time enrolment possible, since a user with no factors cannot yet obtain an
  MFA-scoped access token.

  `authenticator_types` is required; out-of-band enrolment also needs `oob_channels`
  and, for SMS or voice, a `phone_number`.

  The response carries recovery codes **once**, on the first authenticator only.
  Show them to the user then; they cannot be retrieved again.

      iex> Auth0Client.Authentication.Mfa.associate(mfa_token, %{authenticator_types: ["otp"]})
      iex> Auth0Client.Authentication.Mfa.associate(access_token, %{authenticator_types: ["oob"], oob_channels: ["sms"], phone_number: "+15551234567"})
  """
  def associate(token, body) when is_binary(token) and is_map(body) do
    do_post("#{@path}/associate", body, bearer(token))
  end

  @doc """
  Lists the user's enrolled authenticators.

  `token` needs the `read:authenticators` scope and audience
  `https://{your_domain}/mfa/`.

      iex> Auth0Client.Authentication.Mfa.authenticators(access_token)
  """
  def authenticators(token) when is_binary(token) do
    do_get("#{@path}/authenticators", %{}, bearer(token))
  end

  @doc """
  Removes one of the user's authenticators.

  `token` needs the `remove:authenticators` scope and audience
  `https://{your_domain}/mfa/`.

      iex> Auth0Client.Authentication.Mfa.delete_authenticator(access_token, "totp|dev_abc123")
  """
  def delete_authenticator(token, authenticator_id)
      when is_binary(token) and is_binary(authenticator_id) do
    do_delete("#{@path}/authenticators/#{authenticator_id}", %{}, bearer(token))
  end
end
