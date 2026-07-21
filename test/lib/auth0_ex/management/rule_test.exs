defmodule Auth0Ex.Management.RuleTest do
  use ExUnit.Case, async: true
  use Auth0Ex.ReqCase

  alias Auth0Ex.Management.Rule

  describe "all/0,1" do
    test "gets all rules" do
      stub_request([%{"name" => "a-rule"}])

      assert {:ok, [%{"name" => "a-rule"}]} = Rule.all(%{enabled: true})

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/rules"
      assert request.query == %{"enabled" => "true"}
    end

    test "accepts a keyword list of params" do
      stub_request([])

      assert {:ok, []} = Rule.all(enabled: true, fields: "id,name")

      assert assert_receive_request().query == %{
               "enabled" => "true",
               "fields" => "id,name"
             }
    end

    test "sends no params by default" do
      stub_request([])

      assert {:ok, []} = Rule.all()

      request = assert_receive_request()
      assert request.path == "/api/v2/rules"
      assert request.query_string == ""
    end
  end

  describe "get/1,2" do
    test "gets a single rule" do
      stub_request(%{"id" => "some_rule"})

      assert {:ok, %{"id" => "some_rule"}} = Rule.get("some_rule")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/rules/some_rule"
      assert request.query_string == ""
    end

    test "passes through params" do
      stub_request(%{"id" => "some_rule"})

      assert {:ok, _} = Rule.get("some_rule", fields: "id,name")

      assert assert_receive_request().query == %{"fields" => "id,name"}
    end

    test "accepts a map of params" do
      stub_request(%{"id" => "some_rule"})

      assert {:ok, _} = Rule.get("some_rule", %{fields: "id"})

      assert assert_receive_request().query == %{"fields" => "id"}
    end
  end

  describe "create/1" do
    test "posts the body" do
      stub_request(%{"name" => "some_rule"})

      assert {:ok, %{"name" => "some_rule"}} =
               Rule.create(%{name: "some_rule", script: "some_script_code"})

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/rules"
      assert request.body == %{"name" => "some_rule", "script" => "some_script_code"}
    end

    test "accepts a keyword list body" do
      stub_request(%{"name" => "some_rule"})

      assert {:ok, _} = Rule.create(name: "some_rule")

      assert assert_receive_request().body == %{"name" => "some_rule"}
    end
  end

  describe "update/2" do
    test "patches the body" do
      stub_request(%{"name" => "new_name"})

      assert {:ok, _} = Rule.update("some_rule", %{name: "new_name"})

      request = assert_receive_request()
      assert request.method == "PATCH"
      assert request.path == "/api/v2/rules/some_rule"
      assert request.body == %{"name" => "new_name"}
    end

    test "accepts a keyword list body" do
      stub_request(%{"name" => "new_name"})

      assert {:ok, _} = Rule.update("some_rule", name: "new_name")

      assert assert_receive_request().body == %{"name" => "new_name"}
    end
  end

  describe "delete/1" do
    test "deletes and returns :ok on 204" do
      stub_request(fn conn -> Plug.Conn.send_resp(conn, 204, "") end)

      assert :ok = Rule.delete("some_rule")

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/rules/some_rule"
    end
  end

  describe "authorization" do
    test "sends the configured management token" do
      stub_request([])

      assert {:ok, []} = Rule.all()

      assert {"authorization", "Bearer TESTTOKEN"} in assert_receive_request().headers
    end
  end
end
