# Error handling

What every function in this library returns, and how to act on a failure.

## Return shapes

Every API function returns one of three things:

```elixir
{:ok, body}                  # a 2xx with a body, decoded from JSON
:ok                          # a 2xx with no body
{:error, %Auth0Client.Error{}}   # everything else
```

`:ok` covers more than 204. Auth0 answers equivalent mutations with 200, 201 or 204 depending on the
endpoint, and accepted-but-asynchronous ones — deploying an action — with 202. All of them mean the same
thing, so an empty body on any 2xx becomes `:ok` rather than a meaningless `{:ok, ""}`.

## One error shape

Auth0 fails in three unrelated ways — it answers with an error status, the request never reaches it, or no
management token can be obtained — and all three arrive as one struct, so you need one clause rather than
three:

```elixir
case Auth0Client.Management.User.get(user_id) do
  {:ok, user} -> user
  {:error, %Auth0Client.Error{reason: :not_found}} -> nil
  {:error, %Auth0Client.Error{} = error} -> raise error
end
```

`Auth0Client.Error` is an exception, so `raise error` works when you would rather not handle the failure.

## Fields

| Field | |
|---|---|
| `reason` | An atom, always present. See the table below |
| `status` | The HTTP status, or `nil` if the request never got one |
| `body` | The decoded response body |
| `headers` | The response headers |

### Reasons

| Source | Values |
|---|---|
| HTTP status | `:bad_request`, `:unauthorized`, `:forbidden`, `:not_found`, `:conflict`, `:rate_limited`, `:server_error`, `:http_error` |
| Transport | the underlying reason — `:timeout`, `:econnrefused`, and so on |
| Management token | `:token_fetch_failed`, `:missing_access_token`, `:malformed_token`, `:token_fetch_timeout` |

A Management call needs a token before it can be made. When one cannot be obtained the call returns an
error and **never reaches the endpoint you asked for** — so a `:token_fetch_failed` says nothing about
whether that endpoint would have worked.

## Rate limiting

Because response headers are kept, you can honour Auth0's `Retry-After` rather than guessing:

```elixir
{:error, %Auth0Client.Error{reason: :rate_limited} = error} ->
  Process.sleep((Auth0Client.Error.retry_after(error) || 1) * 1000)
```

`retry_after/1` returns seconds, or `nil` when the header is absent or is not a plain number. Auth0 sends
seconds; the HTTP-date form is not parsed, because a wrong date parse would produce a wildly wrong sleep.

See Auth0's [rate limit policy](https://auth0.com/docs/troubleshoot/customer-support/operational-policies/rate-limit-policy)
for the limits themselves.

## Errors that arrive as successes

Two flows report a condition through an error that you are expected to continue from, rather than to
abandon:

- **`mfa_required`** — the password grant answers 403 with an `mfa_token` in the body. That is the start of
  the MFA flow, not a failure. See [MFA](mfa.md)
- **`Job.errors/1` returning `:ok`** — an import that produced no errors answers 204, so the *absence* of
  a body is the good outcome. See [Managing users](users.md)
