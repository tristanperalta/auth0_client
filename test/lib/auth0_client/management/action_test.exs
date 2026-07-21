defmodule Auth0Client.Management.ActionTest do
  use ExUnit.Case, async: true
  use Auth0Client.ReqCase

  alias Auth0Client.Management.Action

  @action_id "act_abc123"

  defp empty(status), do: fn conn -> Plug.Conn.send_resp(conn, status, "") end
  defp accepted(body), do: fn conn -> conn |> Plug.Conn.put_status(202) |> Req.Test.json(body) end

  describe "all/1" do
    test "gets all actions" do
      stub_request(%{"actions" => [%{"id" => @action_id}]})

      assert {:ok, %{"actions" => [_]}} = Action.all()

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/actions/actions"
      assert request.query_string == ""
    end

    test "passes through the documented filters" do
      stub_request(%{})

      Action.all(triggerId: "post-login", actionName: "enrich", deployed: true, installed: false)

      assert assert_receive_request().query == %{
               "triggerId" => "post-login",
               "actionName" => "enrich",
               "deployed" => "true",
               "installed" => "false"
             }
    end

    test "accepts a map with pagination" do
      stub_request(%{})
      Action.all(%{page: 1, per_page: 20})

      assert assert_receive_request().query == %{"page" => "1", "per_page" => "20"}
    end
  end

  describe "get/1" do
    test "gets a single action" do
      stub_request(%{"id" => @action_id})

      assert {:ok, %{"id" => @action_id}} = Action.get(@action_id)

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/actions/actions/#{@action_id}"
    end
  end

  describe "create/1" do
    test "posts the action with supported_triggers as objects, not names" do
      stub_request(%{"id" => @action_id})

      assert {:ok, %{"id" => @action_id}} =
               Action.create(%{
                 name: "enrich-profile",
                 supported_triggers: [%{id: "post-login", version: "v3"}],
                 code: "exports.onExecutePostLogin = async () => {};"
               })

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/actions/actions"

      assert request.body == %{
               "name" => "enrich-profile",
               "supported_triggers" => [%{"id" => "post-login", "version" => "v3"}],
               "code" => "exports.onExecutePostLogin = async () => {};"
             }
    end

    test "carries secrets and dependencies through untouched" do
      stub_request(%{"id" => @action_id})

      Action.create(%{
        name: "a",
        supported_triggers: [%{id: "post-login", version: "v3"}],
        secrets: [%{name: "API_KEY", value: "s3cret"}],
        dependencies: [%{name: "lodash", version: "4.17.21"}]
      })

      body = assert_receive_request().body
      assert body["secrets"] == [%{"name" => "API_KEY", "value" => "s3cret"}]
      assert body["dependencies"] == [%{"name" => "lodash", "version" => "4.17.21"}]
    end
  end

  describe "update/2" do
    test "patches the action" do
      stub_request(%{"id" => @action_id})

      assert {:ok, _} = Action.update(@action_id, %{code: "exports.x = 1;"})

      request = assert_receive_request()
      assert request.method == "PATCH"
      assert request.path == "/api/v2/actions/actions/#{@action_id}"
      assert request.body == %{"code" => "exports.x = 1;"}
    end
  end

  describe "delete/1,2" do
    test "deletes the action" do
      stub_request(empty(204))

      assert :ok = Action.delete(@action_id)

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/actions/actions/#{@action_id}"
      assert request.query_string == ""
    end

    test "passes force, which Auth0 needs to delete a bound action" do
      stub_request(empty(204))

      assert :ok = Action.delete(@action_id, force: true)

      assert assert_receive_request().query == %{"force" => "true"}
    end
  end

  describe "deploy/1" do
    test "posts to the deploy path and returns the accepted version" do
      stub_request(accepted(%{"id" => "ver_1", "deployed" => true}))

      assert {:ok, %{"id" => "ver_1"}} = Action.deploy(@action_id)

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/actions/actions/#{@action_id}/deploy"
    end
  end

  describe "test/2" do
    test "nests the payload under a payload key" do
      stub_request(%{"payload" => %{}})

      assert {:ok, _} = Action.test(@action_id, %{user: %{email: "test@example.com"}})

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/actions/actions/#{@action_id}/test"
      assert request.body == %{"payload" => %{"user" => %{"email" => "test@example.com"}}}
    end
  end

  describe "versions" do
    test "versions/2 lists them" do
      stub_request(%{"versions" => []})

      assert {:ok, %{"versions" => []}} = Action.versions(@action_id)

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/actions/actions/#{@action_id}/versions"
    end

    test "versions/2 supports pagination" do
      stub_request(%{})
      Action.versions(@action_id, per_page: 10)

      assert assert_receive_request().query == %{"per_page" => "10"}
    end

    test "version/2 gets one" do
      stub_request(%{"id" => "ver_1"})

      assert {:ok, %{"id" => "ver_1"}} = Action.version(@action_id, "ver_1")

      assert assert_receive_request().path ==
               "/api/v2/actions/actions/#{@action_id}/versions/ver_1"
    end

    test "deploy_version/3 rolls back to an earlier version" do
      stub_request(accepted(%{"id" => "ver_1"}))

      assert {:ok, %{"id" => "ver_1"}} = Action.deploy_version(@action_id, "ver_1")

      request = assert_receive_request()
      assert request.method == "POST"

      assert request.path ==
               "/api/v2/actions/actions/#{@action_id}/versions/ver_1/deploy"
    end

    test "deploy_version/3 can overwrite the draft" do
      stub_request(accepted(%{"id" => "ver_1"}))

      Action.deploy_version(@action_id, "ver_1", %{update_draft: true})

      assert assert_receive_request().body == %{"update_draft" => true}
    end
  end

  describe "execution/1" do
    test "gets an execution, on the executions path rather than actions" do
      stub_request(%{"id" => "exec_1"})

      assert {:ok, %{"id" => "exec_1"}} = Action.execution("exec_1")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/actions/executions/exec_1"
    end
  end

  describe "triggers" do
    test "triggers/0 lists the available triggers" do
      stub_request(%{"triggers" => [%{"id" => "post-login", "version" => "v3"}]})

      assert {:ok, %{"triggers" => [_]}} = Action.triggers()

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/actions/triggers"
    end

    test "bindings/2 lists what is bound to a trigger" do
      stub_request(%{"bindings" => []})

      assert {:ok, %{"bindings" => []}} = Action.bindings("post-login")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/actions/triggers/post-login/bindings"
    end

    test "bindings/2 supports pagination" do
      stub_request(%{})
      Action.bindings("post-login", page: 2)

      assert assert_receive_request().query == %{"page" => "2"}
    end
  end

  describe "update_bindings/2" do
    test "wraps the list under a bindings key" do
      stub_request(%{"bindings" => []})

      assert {:ok, _} =
               Action.update_bindings("post-login", [
                 %{ref: %{type: "action_id", value: @action_id}, display_name: "Enrich"}
               ])

      request = assert_receive_request()
      assert request.method == "PATCH"
      assert request.path == "/api/v2/actions/triggers/post-login/bindings"

      assert request.body == %{
               "bindings" => [
                 %{
                   "ref" => %{"type" => "action_id", "value" => @action_id},
                   "display_name" => "Enrich"
                 }
               ]
             }
    end

    # Auth0 executes bound actions in the order given, so the wire order is
    # semantic and must survive the round trip exactly as the caller wrote it.
    test "preserves the caller's order" do
      stub_request(%{"bindings" => []})

      Action.update_bindings("post-login", [
        %{ref: %{type: "action_name", value: "first"}},
        %{ref: %{type: "action_name", value: "second"}},
        %{ref: %{type: "action_name", value: "third"}}
      ])

      assert %{"bindings" => bindings} = assert_receive_request().body
      assert Enum.map(bindings, & &1["ref"]["value"]) == ["first", "second", "third"]
    end

    test "an empty list is sent as-is, which unbinds everything" do
      stub_request(%{"bindings" => []})

      assert {:ok, _} = Action.update_bindings("post-login", [])

      assert assert_receive_request().body == %{"bindings" => []}
    end
  end

  describe "paths" do
    test "action functions use Auth0's doubled actions/actions segment" do
      stub_request(%{})
      Action.get(@action_id)
      assert assert_receive_request().path =~ "/api/v2/actions/actions/"
    end

    test "trigger and execution functions do not" do
      stub_request(%{})
      Action.triggers()
      refute assert_receive_request().path =~ "actions/actions"

      stub_request(%{})
      Action.execution("exec_1")
      refute assert_receive_request().path =~ "actions/actions"
    end
  end

  describe "authorization" do
    test "sends the management token" do
      stub_request(%{})
      Action.all()

      assert {"authorization", "Bearer TESTTOKEN"} in assert_receive_request().headers
    end
  end
end
