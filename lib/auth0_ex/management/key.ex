defmodule Auth0Ex.Management.Key do
  @moduledoc """
  A module representing the tenant's cryptographic keys on Auth0.

  Auth0 groups three unrelated kinds of key under `/keys`:

    * **Application signing keys** sign the JWTs your tenant issues. Rotating them
      is routine hygiene
    * **Encryption keys** protect tenant data at rest, and support bringing your
      own root key
    * **Custom signing keys** let you supply the signing material yourself rather
      than using Auth0's

  The function names keep them apart; they are not interchangeable.

  https://auth0.com/docs/api/management/v2/keys
  """

  use Auth0Ex.Api, for: :mgmt
  @path "keys"

  @doc """
  Lists the application signing keys, including which is current and which are
  revoked

      iex> Auth0Ex.Management.Key.signing_keys()
  """
  def signing_keys, do: do_get("#{@path}/signing", %{})

  @doc """
  Gets one application signing key by its key id

      iex> Auth0Ex.Management.Key.signing_key("abc123")
  """
  def signing_key(kid) when is_binary(kid), do: do_get("#{@path}/signing/#{kid}", %{})

  @doc """
  Rotates the application signing key.

  The new key signs everything from now on. Tokens already signed with the previous
  key stay valid until that key is revoked, which is what makes rotation safe: the
  order is rotate, wait for outstanding tokens to expire, then
  `revoke_signing_key/1`. Revoking before they expire rejects every token still in
  circulation.

      iex> Auth0Ex.Management.Key.rotate_signing_key()
  """
  def rotate_signing_key, do: do_post("#{@path}/signing/rotate")

  @doc """
  Revokes an application signing key.

  Every token signed with it stops being accepted immediately. See
  `rotate_signing_key/0` for the safe ordering.

  Auth0 uses `PUT` here rather than `POST` or `DELETE`.

      iex> Auth0Ex.Management.Key.revoke_signing_key("abc123")
  """
  def revoke_signing_key(kid) when is_binary(kid) do
    do_put("#{@path}/signing/#{kid}/revoke")
  end

  @doc """
  Lists the tenant's encryption keys

      iex> Auth0Ex.Management.Key.encryption_keys()
      iex> Auth0Ex.Management.Key.encryption_keys(per_page: 50, include_totals: true)
  """
  def encryption_keys(params \\ %{}) when is_map(params) or is_list(params) do
    do_get("#{@path}/encryption", params)
  end

  @doc """
  Gets one encryption key by its key id

      iex> Auth0Ex.Management.Key.encryption_key("abc123")
  """
  def encryption_key(kid) when is_binary(kid), do: do_get("#{@path}/encryption/#{kid}", %{})

  @doc """
  Creates an encryption key.

  `type` is required — `"customer-provided-root-key"` to bring your own, or
  `"tenant-encryption-key"` for one Auth0 generates.

      iex> Auth0Ex.Management.Key.create_encryption_key(%{type: "tenant-encryption-key"})
  """
  def create_encryption_key(body) when is_map(body), do: do_post("#{@path}/encryption", body)

  @doc """
  Requests a public wrapping key for a customer-provided root key.

  First half of bringing your own key: fetch this wrapping key, encrypt your key
  material with it, then hand the result to `import_encryption_key/2`.

      iex> Auth0Ex.Management.Key.create_wrapping_key("abc123")
  """
  def create_wrapping_key(kid) when is_binary(kid) do
    do_post("#{@path}/encryption/#{kid}/wrapping-key")
  end

  @doc """
  Imports key material wrapped with the key from `create_wrapping_key/1`.

  Second half of bringing your own key.

      iex> Auth0Ex.Management.Key.import_encryption_key("abc123", "base64-wrapped-material")
  """
  def import_encryption_key(kid, wrapped_key) when is_binary(kid) and is_binary(wrapped_key) do
    do_post("#{@path}/encryption/#{kid}", %{wrapped_key: wrapped_key})
  end

  @doc """
  Deletes an encryption key

      iex> Auth0Ex.Management.Key.delete_encryption_key("abc123")
  """
  def delete_encryption_key(kid) when is_binary(kid) do
    do_delete("#{@path}/encryption/#{kid}")
  end

  @doc """
  Rekeys the tenant, re-encrypting its data under a new key

      iex> Auth0Ex.Management.Key.rekey()
  """
  def rekey, do: do_post("#{@path}/encryption/rekey")

  @doc """
  Gets the custom signing keys, if the tenant supplies its own

      iex> Auth0Ex.Management.Key.custom_signing_keys()
  """
  def custom_signing_keys, do: do_get("#{@path}/custom-signing", %{})

  @doc """
  Replaces the custom signing keys.

  Takes a list of JWKs, wrapped under `keys` for you. This replaces the whole set
  rather than adding to it.

      iex> Auth0Ex.Management.Key.replace_custom_signing_keys([%{kty: "RSA", kid: "abc", use: "sig"}])
  """
  def replace_custom_signing_keys(keys) when is_list(keys) do
    do_put("#{@path}/custom-signing", %{keys: keys})
  end

  @doc """
  Removes the custom signing keys, returning the tenant to Auth0-managed signing

      iex> Auth0Ex.Management.Key.delete_custom_signing_keys()
  """
  def delete_custom_signing_keys, do: do_delete("#{@path}/custom-signing")
end
