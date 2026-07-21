defmodule Auth0Ex.Management.LogTest do
  use ExUnit.Case, async: true
  use Auth0Ex.ReqCase

  alias Auth0Ex.Management.Log

  describe "search/1" do
    test "searches logs with a keyword list of params" do
      stub_request([%{"_id" => "log_1"}])

      assert {:ok, [%{"_id" => "log_1"}]} = Log.search(page: 1, fields: "user_name")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/logs"
      assert request.query == %{"page" => "1", "fields" => "user_name"}
    end

    test "accepts a map of params" do
      stub_request([])

      assert {:ok, []} = Log.search(%{q: "type:s", sort: "date:-1"})

      assert assert_receive_request().query == %{"q" => "type:s", "sort" => "date:-1"}
    end

    test "sends no query string for empty params" do
      stub_request([])

      assert {:ok, []} = Log.search(%{})

      assert assert_receive_request().query_string == ""
    end
  end

  describe "get/1" do
    test "gets a single log event" do
      stub_request(%{"_id" => "log_1"})

      assert {:ok, %{"_id" => "log_1"}} = Log.get("log_1")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/logs/log_1"
      assert request.query_string == ""
    end
  end

  describe "authorization" do
    test "sends the configured management token" do
      stub_request([])

      assert {:ok, []} = Log.search(%{})

      assert {"authorization", "Bearer TESTTOKEN"} in assert_receive_request().headers
    end
  end
end
