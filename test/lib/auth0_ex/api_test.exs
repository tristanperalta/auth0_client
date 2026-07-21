defmodule Auth0Ex.ApiTest do
  use ExUnit.Case, async: true
  use Auth0Ex.ReqCase

  defmodule MgmtEndpoint do
    @moduledoc false
    use Auth0Ex.Api, for: :mgmt

    def get_it(path, params \\ %{}), do: do_get(path, params)
    def get_it(path, params, headers), do: do_get(path, params, headers)
    def post_it(path, body \\ %{}), do: do_post(path, body)
    def put_it(path, body \\ %{}), do: do_put(path, body)
    def patch_it(path, body \\ %{}), do: do_patch(path, body)
    def delete_it(path), do: do_delete(path)
    def delete_it(path, params), do: do_delete(path, params)
  end

  defmodule AuthEndpoint do
    @moduledoc false
    use Auth0Ex.Api

    def get_it(path, params \\ %{}), do: do_get(path, params)
    def get_it(path, params, headers), do: do_get(path, params, headers)
    def post_it(path, body, headers), do: do_post(path, body, headers)
    def post_multipart_it(path, fields), do: do_post_multipart(path, fields)
  end

  defmodule DefaultParamsEndpoint do
    @moduledoc false
    use Auth0Ex.Api, for: :mgmt

    def get_it(path, params \\ %{}), do: do_get(path, params)

    defp default_params, do: %{include_totals: true}
  end

  describe "build_url/2" do
    test "prefixes management paths with the v2 api base" do
      assert "https://brighterlink.auth0.com/api/v2/clients?" ==
               MgmtEndpoint.build_url("clients", %{})
    end

    test "authentication paths hang off the tenant root" do
      assert "https://brighterlink.auth0.com/userinfo?" == AuthEndpoint.build_url("userinfo", %{})
    end

    test "encodes query params" do
      url = MgmtEndpoint.build_url("users", %{fields: "name,email"})

      assert url == "https://brighterlink.auth0.com/api/v2/users?fields=name%2Cemail"
    end

    test "encodes a lucene query containing quotes and colons" do
      url = MgmtEndpoint.build_url("users", %{q: "app_metadata.admin:'true'"})

      assert url ==
               "https://brighterlink.auth0.com/api/v2/users?q=app_metadata.admin%3A%27true%27"
    end
  end

  describe "default_params/0" do
    test "is empty by default" do
      assert "https://brighterlink.auth0.com/api/v2/clients?" ==
               MgmtEndpoint.build_url("clients", %{})
    end

    test "an overriding module merges its defaults into every request" do
      url = DefaultParamsEndpoint.build_url("users", %{})

      assert url == "https://brighterlink.auth0.com/api/v2/users?include_totals=true"
    end

    test "explicit params win over the defaults" do
      url = DefaultParamsEndpoint.build_url("users", %{include_totals: false})

      assert url == "https://brighterlink.auth0.com/api/v2/users?include_totals=false"
    end
  end

  describe "verb helpers" do
    test "do_get sends a GET with no body" do
      stub_request(%{})
      MgmtEndpoint.get_it("clients")

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.body == ""
    end

    test "do_get accepts a keyword list of params" do
      stub_request(%{})
      MgmtEndpoint.get_it("clients", fields: "name")

      assert assert_receive_request().query == %{"fields" => "name"}
    end

    test "do_post encodes a map body as JSON" do
      stub_request(%{})
      MgmtEndpoint.post_it("clients", %{name: "app"})

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.body == %{"name" => "app"}
    end

    test "do_post accepts a keyword list body" do
      stub_request(%{})
      MgmtEndpoint.post_it("clients", name: "app")

      assert assert_receive_request().body == %{"name" => "app"}
    end

    test "do_post defaults to an empty json object" do
      stub_request(%{})
      MgmtEndpoint.post_it("clients")

      assert assert_receive_request().body == %{}
    end

    test "do_put encodes a map body as JSON" do
      stub_request(%{})
      MgmtEndpoint.put_it("clients/1", %{name: "app"})

      request = assert_receive_request()
      assert request.method == "PUT"
      assert request.body == %{"name" => "app"}
    end

    test "do_patch encodes a map body as JSON" do
      stub_request(%{})
      MgmtEndpoint.patch_it("clients/1", %{name: "app"})

      request = assert_receive_request()
      assert request.method == "PATCH"
      assert request.body == %{"name" => "app"}
    end

    test "do_patch accepts a keyword list body" do
      stub_request(%{})
      MgmtEndpoint.patch_it("clients/1", name: "app")

      assert assert_receive_request().body == %{"name" => "app"}
    end

    test "do_delete sends a DELETE" do
      stub_request(fn conn -> Plug.Conn.send_resp(conn, 204, "") end)
      assert :ok = MgmtEndpoint.delete_it("clients/1")

      assert assert_receive_request().method == "DELETE"
    end

    test "do_delete can carry query params" do
      stub_request(fn conn -> Plug.Conn.send_resp(conn, 204, "") end)
      MgmtEndpoint.delete_it("user-blocks", %{identifier: "user@example.com"})

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.query == %{"identifier" => "user@example.com"}
    end

    # do_get/2 accepted a keyword list from the start; do_delete/2 did not, and
    # merging one into a map raises BadMapError rather than failing usefully.
    test "do_delete accepts a keyword list of params, like do_get" do
      stub_request(fn conn -> Plug.Conn.send_resp(conn, 204, "") end)
      MgmtEndpoint.delete_it("user-blocks", identifier: "user@example.com")

      assert assert_receive_request().query == %{"identifier" => "user@example.com"}
    end
  end

  describe "headers" do
    test "management requests carry the bearer token" do
      stub_request(%{})
      MgmtEndpoint.get_it("clients")

      headers = assert_receive_request().headers
      assert {"authorization", "Bearer TESTTOKEN"} in headers
      assert {"content-type", "application/json"} in headers
    end

    test "authentication requests carry no bearer token" do
      stub_request(%{})
      AuthEndpoint.get_it("userinfo")

      headers = assert_receive_request().headers
      refute Enum.any?(headers, &match?({"authorization", _}, &1))
    end
  end

  describe "per-request headers" do
    test "do_get/3 merges extra headers into the defaults" do
      stub_request(%{})
      AuthEndpoint.get_it("userinfo", %{}, [{"Authorization", "Bearer USER_TOKEN"}])

      headers = assert_receive_request().headers
      assert {"authorization", "Bearer USER_TOKEN"} in headers
      assert {"content-type", "application/json"} in headers
    end

    test "do_post/3 merges extra headers into the defaults" do
      stub_request(%{})
      AuthEndpoint.post_it("mfa/challenge", %{}, [{"Authorization", "Bearer MFA_TOKEN"}])

      headers = assert_receive_request().headers
      assert {"authorization", "Bearer MFA_TOKEN"} in headers
    end

    test "an extra authorization replaces the management token rather than duplicating it" do
      stub_request(%{})
      MgmtEndpoint.get_it("clients", %{}, [{"Authorization", "Bearer OVERRIDE"}])

      headers = assert_receive_request().headers
      assert Enum.count(headers, &match?({"authorization", _}, &1)) == 1
      assert {"authorization", "Bearer OVERRIDE"} in headers
    end
  end

  describe "do_post_multipart/2" do
    defp content_type(request) do
      request.headers |> List.keyfind("content-type", 0) |> elem(1)
    end

    # Req sets the multipart content-type with put_new_header, so the default
    # application/json has to be removed or it wins and the boundary is lost.
    test "replaces the default json content type with a multipart one" do
      stub_request(%{})
      AuthEndpoint.post_multipart_it("upload", file: {"contents", filename: "a.json"})

      type = content_type(assert_receive_request())
      assert type =~ "multipart/form-data"
      assert type =~ "boundary="
      refute type =~ "application/json"
    end

    test "sends exactly one content-type header" do
      stub_request(%{})
      AuthEndpoint.post_multipart_it("upload", field: "value")

      headers = assert_receive_request().headers
      assert Enum.count(headers, &match?({"content-type", _}, &1)) == 1
    end

    test "keeps the other default headers" do
      stub_request(%{})
      AuthEndpoint.post_multipart_it("upload", field: "value")

      assert List.keyfind(assert_receive_request().headers, "user-agent", 0)
    end

    test "encodes each field as a part" do
      stub_request(%{})
      AuthEndpoint.post_multipart_it("upload", one: "first", two: "second")

      body = assert_receive_request().body
      assert body =~ ~s(name="one")
      assert body =~ "first"
      assert body =~ ~s(name="two")
      assert body =~ "second"
    end
  end

  describe "path segments needing escapes" do
    test "a user id containing a pipe survives the round trip" do
      stub_request(%{"user_id" => "auth0|abc123"})

      assert {:ok, _} = MgmtEndpoint.get_it("users/auth0|abc123")

      assert assert_receive_request().path == "/api/v2/users/auth0|abc123"
    end
  end
end
