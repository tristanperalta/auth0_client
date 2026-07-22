defmodule Auth0Client.Management.CustomDomain do
  @moduledoc """
  A module representing custom domains on Auth0.

  A custom domain serves login from `auth.yourapp.com` rather than
  `your-tenant.auth0.com`, so users never see the tenant URL.

  Setting one up is a sequence, and the order matters:

    1. `create/1` registers the domain and returns the DNS record to add
    2. add that record with your DNS provider
    3. `verify/1` tells Auth0 to check for it — the domain stays in
       `pending_verification` until this succeeds
    4. `set_default/1` promotes it, once verified

  https://auth0.com/docs/api/management/v2/custom-domains
  """

  use Auth0Client.Api, for: :mgmt
  @path "custom-domains"

  @doc """
  Gets all custom domains.

  Supports checkpoint pagination (`from` / `take`), `q` and `sort`.

      iex> Auth0Client.Management.CustomDomain.all()
      iex> Auth0Client.Management.CustomDomain.all(take: 10)
  """
  def all(params \\ %{}) when is_map(params) or is_list(params) do
    do_get(@path, params)
  end

  @doc """
  Gets a custom domain by id

      iex> Auth0Client.Management.CustomDomain.get("cd_abc123")
  """
  def get(id) when is_binary(id), do: do_get("#{@path}/#{id}")

  @doc """
  Registers a custom domain.

  `domain` and `type` are required. `type` is `"auth0_managed_certs"` — Auth0
  provisions and renews the certificate — or `"self_managed_certs"`, where you
  terminate TLS yourself.

  The response carries the `verification` record you must add to DNS. The domain
  does nothing until `verify/1` confirms it.

      iex> Auth0Client.Management.CustomDomain.create(%{domain: "auth.example.com", type: "auth0_managed_certs"})
  """
  def create(body) when is_map(body), do: do_post(@path, body)

  @doc """
  Updates a custom domain.

  Only `tls_policy`, `custom_client_ip_header`, `domain_metadata` and
  `relying_party_identifier` can change. `domain` and `type` are fixed at creation
  — to change either, delete the domain and register it again.

      iex> Auth0Client.Management.CustomDomain.update("cd_abc123", %{tls_policy: "recommended"})
  """
  def update(id, body) when is_binary(id), do: do_patch("#{@path}/#{id}", body)

  @doc """
  Deletes a custom domain.

  Logins fall back to the tenant domain, so anything hard-coded against the custom
  one breaks.

      iex> Auth0Client.Management.CustomDomain.delete("cd_abc123")
  """
  def delete(id) when is_binary(id), do: do_delete("#{@path}/#{id}")

  @doc """
  Asks Auth0 to check the DNS record and verify the domain.

  Call it after adding the record from `create/1`. Verification can take a few
  minutes to propagate; the response reports the current status.

      iex> Auth0Client.Management.CustomDomain.verify("cd_abc123")
  """
  def verify(id) when is_binary(id), do: do_post("#{@path}/#{id}/verify")

  @doc """
  Tests a custom domain's configuration

      iex> Auth0Client.Management.CustomDomain.test("cd_abc123")
  """
  def test(id) when is_binary(id), do: do_post("#{@path}/#{id}/test")

  @doc """
  Gets the tenant's default custom domain — the one users are sent to

      iex> Auth0Client.Management.CustomDomain.default()
  """
  def default, do: do_get("#{@path}/default")

  @doc """
  Promotes a verified custom domain to be the tenant's default.

  Takes the **domain name**, not the id that every other function here takes —
  that asymmetry is Auth0's.

      iex> Auth0Client.Management.CustomDomain.set_default("auth.example.com")
  """
  def set_default(domain) when is_binary(domain) do
    do_patch("#{@path}/default", %{domain: domain})
  end
end
