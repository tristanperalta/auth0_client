defmodule Auth0Client.Management.Action do
  @moduledoc """
  A module representing actions on Auth0.

  Actions are Auth0's extensibility model: Node functions that run at points in the
  login flow. They replace Rules, which Auth0 has made read-only and ends on
  2026-11-18.

  The work comes in three steps, and the third is the one people forget:

    1. `create/1` an action, naming the triggers it supports
    2. `deploy/1` it, which makes a version live
    3. `update_bindings/2` to *bind* it to a trigger

  An action that is never bound never runs, no matter how many times it is deployed.

  The `/actions/modules` endpoints, which share reusable code between actions, are
  not wrapped here.

  https://auth0.com/docs/api/management/v2/actions
  """

  use Auth0Client.Api, for: :mgmt
  @path "actions"
  @actions "actions/actions"

  @doc """
  Gets all actions.

  Filters: `triggerId`, `actionName`, `deployed`, `installed`, plus `page` and
  `per_page`.

      iex> Auth0Client.Management.Action.all()
      iex> Auth0Client.Management.Action.all(triggerId: "post-login", deployed: true)
  """
  def all(params \\ %{}) when is_map(params) or is_list(params) do
    do_get(@actions, params)
  end

  @doc """
  Gets a single action

      iex> Auth0Client.Management.Action.get("act_abc123")
  """
  def get(id) when is_binary(id), do: do_get("#{@actions}/#{id}", %{})

  @doc """
  Creates an action.

  `name` and `supported_triggers` are required. `supported_triggers` is a list of
  objects, not names — `[%{id: "post-login", version: "v3"}]`. Use `triggers/0` to
  see the available ids and their current versions.

      iex> Auth0Client.Management.Action.create(%{
      ...>   name: "enrich-profile",
      ...>   supported_triggers: [%{id: "post-login", version: "v3"}],
      ...>   code: "exports.onExecutePostLogin = async (event, api) => {};"
      ...> })
  """
  def create(body), do: do_post(@actions, body)

  @doc """
  Updates an action's code, dependencies, secrets or supported triggers.

  Changes affect the draft; call `deploy/1` to make them live.

      iex> Auth0Client.Management.Action.update("act_abc123", %{code: "exports.onExecutePostLogin = async () => {};"})
  """
  def update(id, body) when is_binary(id), do: do_patch("#{@actions}/#{id}", body)

  @doc """
  Deletes an action.

  Auth0 refuses to delete an action that is still bound to a trigger; pass
  `force: true` to delete it anyway.

      iex> Auth0Client.Management.Action.delete("act_abc123")
      iex> Auth0Client.Management.Action.delete("act_abc123", force: true)
  """
  def delete(id, params \\ %{}) when is_binary(id) do
    do_delete("#{@actions}/#{id}", params)
  end

  @doc """
  Deploys an action, creating a new version from the current draft.

  Auth0 accepts this asynchronously and answers `202`, so a successful return means
  the deployment was accepted rather than finished. Poll `get/1` for the status.

      iex> Auth0Client.Management.Action.deploy("act_abc123")
  """
  def deploy(id) when is_binary(id), do: do_post("#{@actions}/#{id}/deploy")

  @doc """
  Runs an action against a test payload without deploying it.

  The payload is nested under `payload` for you.

      iex> Auth0Client.Management.Action.test("act_abc123", %{user: %{email: "test@example.com"}})
  """
  def test(id, payload) when is_binary(id) and is_map(payload) do
    do_post("#{@actions}/#{id}/test", %{payload: payload})
  end

  @doc """
  Gets an action's deployed versions

      iex> Auth0Client.Management.Action.versions("act_abc123")
      iex> Auth0Client.Management.Action.versions("act_abc123", per_page: 10)
  """
  def versions(action_id, params \\ %{}) when is_binary(action_id) do
    do_get("#{@actions}/#{action_id}/versions", params)
  end

  @doc """
  Gets a specific version of an action

      iex> Auth0Client.Management.Action.version("act_abc123", "ver_1")
  """
  def version(action_id, version_id) when is_binary(action_id) and is_binary(version_id) do
    do_get("#{@actions}/#{action_id}/versions/#{version_id}", %{})
  end

  @doc """
  Rolls an action back to an earlier version by redeploying it.

  Pass `%{update_draft: true}` to overwrite the draft with that version's code as
  well. Like `deploy/1`, Auth0 answers `202`.

      iex> Auth0Client.Management.Action.deploy_version("act_abc123", "ver_1")
      iex> Auth0Client.Management.Action.deploy_version("act_abc123", "ver_1", %{update_draft: true})
  """
  def deploy_version(action_id, version_id, body \\ %{})
      when is_binary(action_id) and is_binary(version_id) do
    do_post("#{@actions}/#{action_id}/versions/#{version_id}/deploy", body)
  end

  @doc """
  Gets the details of an action execution, including logs from each bound action

      iex> Auth0Client.Management.Action.execution("exec_abc123")
  """
  def execution(id) when is_binary(id), do: do_get("#{@path}/executions/#{id}", %{})

  @doc """
  Gets the available triggers and their current versions.

  Use this to find the `id` and `version` for `create/1`'s `supported_triggers`.

      iex> Auth0Client.Management.Action.triggers()
  """
  def triggers, do: do_get("#{@path}/triggers", %{})

  @doc """
  Gets the actions currently bound to a trigger, in execution order

      iex> Auth0Client.Management.Action.bindings("post-login")
  """
  def bindings(trigger_id, params \\ %{}) when is_binary(trigger_id) do
    do_get("#{@path}/triggers/#{trigger_id}/bindings", params)
  end

  @doc """
  Sets the actions bound to a trigger.

  > #### This replaces every binding on the trigger {: .warning}
  >
  > It is not additive. Passing one binding unbinds every other action on that
  > trigger. Read `bindings/2` first and pass the existing list back with your
  > change applied.

  Order is significant — Auth0 executes bound actions in the order given.

  Each binding is `%{ref: %{type: "action_id", value: id}, display_name: name}`;
  `ref` may also use `type: "action_name"`.

      iex> Auth0Client.Management.Action.update_bindings("post-login", [
      ...>   %{ref: %{type: "action_id", value: "act_abc123"}, display_name: "Enrich profile"}
      ...> ])
  """
  def update_bindings(trigger_id, bindings) when is_binary(trigger_id) and is_list(bindings) do
    do_patch("#{@path}/triggers/#{trigger_id}/bindings", %{bindings: bindings})
  end
end
