defmodule Auth0Ex.Management.Client do
  @moduledoc """
  A module representing clients — applications — on Auth0.

  Beyond the application itself, this covers **client credentials**: the public
  keys and certificates that let an application authenticate with Private Key JWT
  or mTLS instead of a shared secret. Registering one is two steps, and the second
  is easy to miss — see `create_credential/2`.

  https://auth0.com/docs/api/management/v2/clients
  """

  use Auth0Ex.Api, for: :mgmt
  @path "clients"

  @doc """
  Gets all the clients

  Searching with `q` needs checkpoint pagination — pass `from` and `take` rather
  than `page` — and carries lower rate limits than an unfiltered listing.

      iex> Auth0Ex.Management.Client.all()
      iex> Auth0Ex.Management.Client.all(fields: "name,client_id")
      iex> Auth0Ex.Management.Client.all(q: "name:acme*", take: 50)
  """
  def all(params \\ %{}) when is_map(params) or is_list(params) do
    do_get(@path, params)
  end

  @doc """
  Gets the information for individual client

      iex> Auth0Ex.Management.Client.get("some_id")
      iex> Auth0Ex.Management.Client.get("some_id", [fields: "id,client_id", include_fields: true])
  """
  def get(id) when is_binary(id), do: get(id, [])

  def get(id, params) when is_binary(id) and (is_map(params) or is_list(params)) do
    do_get("#{@path}/#{id}", params)
  end

  @doc """
  Creates a new Auth0 client from given body

      iex> Auth0Ex.Management.Client.create(%{name: "Samars App"})
  """
  def create(body) do
    do_post(@path, body)
  end

  @doc """
  Updates Auth0 client of given ID with given body

      iex> Auth0Ex.Management.Client.update("some_client_id", %{name: "New Client Name"})
  """
  def update(id, body) do
    do_patch("#{@path}/#{id}", body)
  end

  @doc """
  Deletes the client with given client id

      iex> Auth0Ex.Management.Client.delete("some_client_id")
  """
  def delete(id) do
    do_delete("#{@path}/#{id}")
  end

  @doc """
  Rotate a client secret for client with given ID

      iex> Auth0Ex.Management.Client.rotate_secret("some_client_id")
  """
  def rotate_secret(id) do
    do_post("#{@path}/#{id}/rotate-secret")
  end

  @doc """
  Lists the connections enabled for a client.

  Filter by `strategy`; supports checkpoint pagination with `from` and `take`.

      iex> Auth0Ex.Management.Client.connections("some_client_id")
      iex> Auth0Ex.Management.Client.connections("some_client_id", strategy: "auth0")
  """
  def connections(id, params \\ %{}) when is_binary(id) do
    do_get("#{@path}/#{id}/connections", params)
  end

  @doc """
  Lists a client's credentials

      iex> Auth0Ex.Management.Client.credentials("some_client_id")
  """
  def credentials(id) when is_binary(id), do: do_get("#{@path}/#{id}/credentials", %{})

  @doc """
  Gets one client credential

      iex> Auth0Ex.Management.Client.credential("some_client_id", "cred_abc123")
  """
  def credential(id, credential_id) when is_binary(id) and is_binary(credential_id) do
    do_get("#{@path}/#{id}/credentials/#{credential_id}", %{})
  end

  @doc """
  Registers a credential for Private Key JWT or mTLS authentication.

  `credential_type` is required — `"public_key"` for Private Key JWT,
  `"cert_subject_dn"` or `"x509_cert"` for mTLS. A public key also takes `pem` and
  `alg` (`RS256`, `RS384` or `PS256`).

  > #### Registering a credential does not enable it {: .warning}
  >
  > Auth0 will not use the credential until the application says it should. Follow
  > this with `update/2`, setting `client_authentication_methods` — until then the
  > credential exists and does nothing.

      iex> Auth0Ex.Management.Client.create_credential("some_client_id", %{
      ...>   credential_type: "public_key",
      ...>   name: "Deploy key",
      ...>   pem: "-----BEGIN PUBLIC KEY-----...",
      ...>   alg: "RS256"
      ...> })
  """
  def create_credential(id, body) when is_binary(id) and is_map(body) do
    do_post("#{@path}/#{id}/credentials", body)
  end

  @doc """
  Updates a client credential.

  Only `expires_at` can change; everything else is fixed at creation. Auth0 answers
  this `PATCH` with `201` rather than `200`.

      iex> Auth0Ex.Management.Client.update_credential("some_client_id", "cred_abc123", %{expires_at: "2027-01-01T00:00:00Z"})
  """
  def update_credential(id, credential_id, body)
      when is_binary(id) and is_binary(credential_id) do
    do_patch("#{@path}/#{id}/credentials/#{credential_id}", body)
  end

  @doc """
  Deletes a client credential.

  If the application still lists it in `client_authentication_methods`, it can no
  longer authenticate — remove it there first.

      iex> Auth0Ex.Management.Client.delete_credential("some_client_id", "cred_abc123")
  """
  def delete_credential(id, credential_id) when is_binary(id) and is_binary(credential_id) do
    do_delete("#{@path}/#{id}/credentials/#{credential_id}")
  end

  @doc """
  Validates a Client ID Metadata Document (CIMD) without creating anything.

  Fetches the document and reports how its fields would map onto an Auth0
  application. Useful for checking a document before registering it.

      iex> Auth0Ex.Management.Client.preview_metadata_document(%{external_client_id: "https://app.example.com/metadata"})
  """
  def preview_metadata_document(body) when is_map(body) do
    do_post("#{@path}/cimd/preview", body)
  end

  @doc """
  Registers or updates an application from a Client ID Metadata Document (CIMD).

  Idempotent, keyed on `external_client_id`: Auth0 answers `201` when it creates the
  application and `200` when it updates an existing one. Both are success, and this
  library returns `{:ok, client}` either way.

      iex> Auth0Ex.Management.Client.register_metadata_document(%{external_client_id: "https://app.example.com/metadata"})
  """
  def register_metadata_document(body) when is_map(body) do
    do_post("#{@path}/cimd/register", body)
  end
end
