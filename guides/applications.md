# Applications and credentials

Managing Auth0 applications — clients, in the API's language — and the credentials they authenticate
with. For requesting tokens as an application, see [Logging users in](login.md).

Assumes Management API credentials are configured — see [Configuration](configuration.md).

Auth0 reference: [Clients](https://auth0.com/docs/api/management/v2/clients),
[Client grants](https://auth0.com/docs/api/management/v2/client-grants).

## The basics

```elixir
alias Auth0Ex.Management.Client

Client.all(fields: "name,client_id")
Client.get("abc123")
Client.create(%{name: "Backend service", app_type: "non_interactive"})
Client.update("abc123", %{name: "Renamed"})
Client.delete("abc123")

Client.connections("abc123")        # which identity providers it can use
Client.rotate_secret("abc123")
```

Searching with `q` needs checkpoint pagination — `from` and `take` rather than `page` — and carries lower
rate limits.

## Private Key JWT and mTLS

Instead of a shared client secret, an application can authenticate with a key it holds privately. That is
more secure, because the secret never leaves your deployment.

Setting it up is **two steps**, and the second is the one people miss:

```elixir
# 1. register the public key
{:ok, credential} = Client.create_credential("abc123", %{
  credential_type: "public_key",
  name: "Deploy key",
  pem: File.read!("public.pem"),
  alg: "RS256"
})

# 2. tell the application to use it — until this runs, the credential does nothing
Client.update("abc123", %{
  client_authentication_methods: %{
    private_key_jwt: %{credentials: [%{id: credential["id"]}]}
  }
})
```

> #### A registered credential is not an enabled one {: .warning}
>
> Auth0 ignores the credential until the application's `client_authentication_methods` names it. Nothing
> errors in between — the application simply keeps using its shared secret.

`credential_type` is `"public_key"` for Private Key JWT, or `"cert_subject_dn"` / `"x509_cert"` for mTLS.

Credentials can be listed, inspected and removed:

```elixir
Client.credentials("abc123")
Client.credential("abc123", credential["id"])
Client.update_credential("abc123", credential["id"], %{expires_at: "2027-01-01T00:00:00Z"})
Client.delete_credential("abc123", credential["id"])
```

Only `expires_at` is mutable — everything else is fixed when the credential is created. And remove the
credential from `client_authentication_methods` *before* deleting it, or the application is left unable to
authenticate.

### Using the credential

Once enabled, request tokens by signing a JWT with the private key and passing it as `client_assertion`.
There is no shared secret, so `client_secret` is `nil`:

```elixir
Auth0Ex.Authentication.Token.client_credentials(client_id, nil, "https://your-api/", %{
  client_assertion: signed_jwt,
  client_assertion_type: "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
})
```

This library does not sign the assertion for you — build it with a JOSE library, using the key whose public
half you registered above.

## Client ID Metadata Documents

CIMD registers an application from a metadata document you host, rather than from a payload. Registration
is idempotent, keyed on `external_client_id`:

```elixir
# check how the document maps before committing to it
Client.preview_metadata_document(%{external_client_id: "https://app.example.com/metadata"})

# create or update
Client.register_metadata_document(%{external_client_id: "https://app.example.com/metadata"})
```

## Client grants

A client grant authorises an application to request tokens for an API, with a fixed set of scopes.

```elixir
alias Auth0Ex.Management.ClientGrant

ClientGrant.all(audience: "https://api.example.com")
ClientGrant.get("cgr_abc123")
ClientGrant.create(%{client_id: "abc123", audience: "https://api.example.com", scope: ["read:things"]})
ClientGrant.update("cgr_abc123", %{scope: ["read:things", "write:things"]})
ClientGrant.delete("cgr_abc123")

# which organizations this grant applies to
ClientGrant.organizations("cgr_abc123")
```

Do not confuse these with `Auth0Ex.Management.Grant`, which records an end user's *consent* — see
[Managing users](users.md).
