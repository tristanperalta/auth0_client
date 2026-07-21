# Custom domains and keys

Two production-hardening tasks: serving login from your own domain, and rotating the keys that sign your
tokens. Both are sequences where the order matters more than the individual calls.

Assumes Management API credentials are configured — see [Configuration](configuration.md).

Auth0 reference: [Custom domains](https://auth0.com/docs/api/management/v2/custom-domains),
[Keys](https://auth0.com/docs/api/management/v2/keys).

## Setting up a custom domain

A custom domain serves login from `auth.yourapp.com` instead of `your-tenant.auth0.com`. Four steps, and
skipping the third leaves it inert:

```elixir
alias Auth0Ex.Management.CustomDomain

# 1. register it — the response carries the DNS record you must add
{:ok, domain} = CustomDomain.create(%{
  domain: "auth.example.com",
  type: "auth0_managed_certs"
})
#=> {:ok, %{"custom_domain_id" => "cd_abc123",
#=>         "status" => "pending_verification",
#=>         "verification" => %{"methods" => [...]}}}

# 2. add that record with your DNS provider

# 3. tell Auth0 to check for it
CustomDomain.verify(domain["custom_domain_id"])
#=> {:ok, %{"status" => "ready"}}

# 4. promote it — note this takes the domain NAME, not the id
CustomDomain.set_default("auth.example.com")
```

The domain stays in `pending_verification` until step 3 succeeds, and DNS propagation means `verify/1` may
need retrying for a few minutes.

`type` is `"auth0_managed_certs"`, where Auth0 provisions and renews the certificate, or
`"self_managed_certs"`, where you terminate TLS yourself.

`domain` and `type` are fixed once created. `update/2` changes only `tls_policy`,
`custom_client_ip_header`, `domain_metadata` and `relying_party_identifier` — renaming means deleting and
registering again.

## Rotating signing keys

These are the keys Auth0 signs your JWTs with. Rotation is two steps separated by time, and doing them
back to back is what causes an outage:

```elixir
alias Auth0Ex.Management.Key

Key.signing_keys()
#=> {:ok, [%{"kid" => "abc", "current" => true}, %{"kid" => "xyz", "next" => true}]}

# 1. rotate — the new key signs from now on
Key.rotate_signing_key()

# 2. LATER, once tokens signed with the old key have expired
Key.revoke_signing_key("abc")
```

> #### Revoking too early rejects tokens still in circulation {: .warning}
>
> After `rotate_signing_key/0`, tokens signed with the previous key remain valid — that overlap is what
> makes rotation safe. `revoke_signing_key/1` ends it immediately, so wait at least as long as your access
> token lifetime before calling it.

`revoke_signing_key/1` is a `PUT` in Auth0's API, unlike every other revoke-shaped call.

Applications verifying tokens against [`Authentication.jwks/0`](login.md) pick up the new key
automatically, provided they are not caching the key set past its rotation.

## Encryption keys

Tenant data encryption, including bringing your own root key:

```elixir
Key.encryption_keys()
Key.create_encryption_key(%{type: "tenant-encryption-key"})
```

To supply your own root key, request a wrapping key, encrypt your material with it, and import the result:

```elixir
{:ok, %{"public_key" => public_key}} = Key.create_wrapping_key(kid)

# wrap your key material with public_key, then
Key.import_encryption_key(kid, wrapped_material)
```

`Key.rekey/0` re-encrypts tenant data under a new key.

## Custom signing keys

To sign with your own key material rather than Auth0's:

```elixir
Key.custom_signing_keys()
Key.replace_custom_signing_keys([%{kty: "RSA", kid: "abc", use: "sig"}])
Key.delete_custom_signing_keys()   # back to Auth0-managed signing
```

`replace_custom_signing_keys/1` replaces the whole set rather than adding to it.
