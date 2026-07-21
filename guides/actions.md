# Actions

Actions are Auth0's extensibility model — Node functions that run at points in the login flow. They replace
Rules, which Auth0 has made read-only and ends on 2026-11-18.

Assumes Management API credentials are configured — see [Configuration](configuration.md).

Auth0 reference: [Actions](https://auth0.com/docs/api/management/v2/actions).

## Create, deploy, bind

Three steps, and the third is the one people miss.

```elixir
alias Auth0Client.Management.Action

# 1. create — supported_triggers takes objects, not names.
#    Action.triggers() lists the available ids and versions.
{:ok, action} = Action.create(%{
  name: "enrich-profile",
  supported_triggers: [%{id: "post-login", version: "v3"}],
  code: "exports.onExecutePostLogin = async (event, api) => {};"
})

# 2. deploy — Auth0 accepts this asynchronously and answers 202
Action.deploy(action["id"])

# 3. bind — until this runs, the action never executes
Action.update_bindings("post-login", [
  %{ref: %{type: "action_id", value: action["id"]}, display_name: "Enrich profile"}
])
```

An action that is created and deployed but never bound is inert. Nothing errors; it simply never runs.

## Binding replaces, it does not append

> #### `update_bindings/2` replaces every binding on the trigger {: .warning}
>
> It is not additive. Passing one binding unbinds every other action on that trigger. The order you give is
> the order Auth0 executes them in.

To add an action without disturbing the others, read the current list first:

```elixir
{:ok, %{"bindings" => existing}} = Action.bindings("post-login")

Action.update_bindings("post-login", existing ++ [new_binding])
```

## Iterating

`update/2` changes the draft; `deploy/1` makes it live. To try a change without deploying it:

```elixir
Action.test(action["id"], %{user: %{email: "test@example.com"}})
```

Versions are kept, so a bad deploy can be rolled back by redeploying an earlier one:

```elixir
Action.versions(action["id"])
Action.deploy_version(action["id"], "ver_abc123")
```

Pass `%{update_draft: true}` to overwrite the draft with that version's code as well, rather than only
redeploying it.

## Deleting

Auth0 refuses to delete an action that is still bound to a trigger. Either unbind it first, or force it:

```elixir
Action.delete(action["id"], force: true)
```

## Debugging a run

`Action.execution/1` returns the details of one execution, including logs from each action bound to the
trigger — the place to look when an action ran but did not do what you expected.
