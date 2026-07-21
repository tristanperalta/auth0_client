# Managing users

Creating, finding and updating users, and moving them in and out in bulk. For roles and permissions see
[RBAC](rbac.md); for MFA enrolment see [MFA](mfa.md).

Assumes Management API credentials are configured — see [Configuration](configuration.md).

Auth0 reference: [Users](https://auth0.com/docs/api/management/v2/users),
[Jobs](https://auth0.com/docs/api/management/v2/jobs).

## The basics

```elixir
alias Auth0Ex.Management.User

User.all(%{q: "email:*@example.com"})
#=> {:ok, [%{"user_id" => "auth0|abc123", ...}]}

User.get("auth0|abc123", %{fields: "email,name"})
#=> {:ok, %{"email" => "someone@example.com", "name" => "Someone"}}

User.create("Username-Password-Authentication", %{
  email: "someone@example.com",
  password: "a-strong-password"
})

User.update("auth0|abc123", %{app_metadata: %{admin: true}})

User.delete("auth0|abc123")
#=> :ok
```

## Searching

`User.all/1` uses the v3 search engine, the only one Auth0 still supports. It differs from v2 in ways that
return nothing rather than erroring:

- `.raw` sub-fields are gone — query the field directly
- `connection` became `identities.connection`
- matching is case-sensitive
- **results cap at 1,000 records**

For anything larger, run an export rather than paginating.

## Password resets

To email the user a reset link, use `Auth0Ex.Authentication.change_password/3` — see
[Logging users in](login.md). To generate a link yourself:

```elixir
Auth0Ex.Management.Ticket.password_change(%{user_id: "auth0|abc123"})
#=> {:ok, %{"ticket" => "https://your-tenant.auth0.com/lo/reset?ticket=..."}}
```

## Sessions and tokens

```elixir
User.sessions("auth0|abc123")
User.delete_sessions("auth0|abc123")       # signs them out everywhere

User.refresh_tokens("auth0|abc123")
User.delete_refresh_tokens("auth0|abc123")

User.revoke_access("auth0|abc123")         # both at once
```

## Bulk import and export

Jobs are asynchronous: they return immediately and do the work in the background, so start one, poll it,
then check for errors.

```elixir
alias Auth0Ex.Management.Job

# Export — poll until the job carries a `location` to download from
{:ok, job} = Job.users_exports(%{connection_id: "con_abc123", format: "json"})
{:ok, %{"status" => "completed", "location" => url}} = Job.get(job["id"])

# Import — takes the contents of a JSON file, or a stream for a large one
{:ok, job} = Job.users_imports(File.read!("users.json"), "con_abc123", %{upsert: true})
{:ok, job} = Job.users_imports(File.stream!("users.json"), "con_abc123")
```

Import is the one endpoint Auth0 accepts only as `multipart/form-data`; the library handles that for you,
including turning `upsert: true` into the string form Auth0 expects.

### Checking the result

`Job.errors/1` answers `:ok` when the import was clean and `{:ok, errors}` when some records failed —
Auth0 returns 204 in the first case. The success path is the surprising one, so match both:

```elixir
case Job.errors(job["id"]) do
  :ok -> :imported_cleanly
  {:ok, errors} -> handle(errors)
end
```
