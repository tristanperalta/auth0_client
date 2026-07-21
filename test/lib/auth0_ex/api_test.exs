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
    def delete_it(path, params, headers), do: do_delete(path, params, headers)

    # Every verb, called with a third argument of extra headers.
    def with_headers(:get, path, headers), do: do_get(path, %{}, headers)
    def with_headers(:post, path, headers), do: do_post(path, %{}, headers)
    def with_headers(:put, path, headers), do: do_put(path, %{}, headers)
    def with_headers(:patch, path, headers), do: do_patch(path, %{}, headers)
    def with_headers(:delete, path, headers), do: do_delete(path, %{}, headers)
    def with_headers(:delete_body, path, headers), do: do_delete_body(path, %{}, headers)
    def with_headers(:post_form, path, headers), do: do_post_form(path, %{}, headers)
    def with_headers(:post_multipart, path, headers), do: do_post_multipart(path, [], headers)
  end

  defmodule AuthEndpoint do
    @moduledoc false
    use Auth0Ex.Api

    def get_it(path, params \\ %{}), do: do_get(path, params)
    def get_it(path, params, headers), do: do_get(path, params, headers)
    def post_it(path, body, headers), do: do_post(path, body, headers)
    def post_multipart_it(path, fields), do: do_post_multipart(path, fields)
    def delete_it(path, params, headers), do: do_delete(path, params, headers)
  end

  defmodule DefaultParamsEndpoint do
    @moduledoc false
    use Auth0Ex.Api, for: :mgmt

    def get_it(path, params \\ %{}), do: do_get(path, params)

    defp default_params, do: %{include_totals: true}
  end

  describe "build_url/2" do
    test "prefixes management paths with the v2 api base" do
      assert "https://brighterlink.auth0.com/api/v2/clients" ==
               MgmtEndpoint.build_url("clients", %{})
    end

    test "authentication paths hang off the tenant root" do
      assert "https://brighterlink.auth0.com/userinfo" == AuthEndpoint.build_url("userinfo", %{})
    end

    test "appends no question mark when there are no params" do
      refute MgmtEndpoint.build_url("clients", %{}) =~ "?"
      refute AuthEndpoint.build_url("userinfo", []) =~ "?"
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
      assert "https://brighterlink.auth0.com/api/v2/clients" ==
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

    # do_get/3 and do_post/3 gained extra headers when userinfo needed them;
    # do_delete only caught up when /mfa/authenticators did.
    test "do_delete/3 merges extra headers" do
      stub_request(fn conn -> Plug.Conn.send_resp(conn, 204, "") end)
      AuthEndpoint.delete_it("mfa/authenticators/totp|1", %{}, [{"Authorization", "Bearer USER"}])

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert {"authorization", "Bearer USER"} in request.headers
    end

    test "do_delete/3 replaces rather than duplicates the authorization" do
      stub_request(fn conn -> Plug.Conn.send_resp(conn, 204, "") end)
      MgmtEndpoint.delete_it("clients/1", %{}, [{"Authorization", "Bearer OVERRIDE"}])

      headers = assert_receive_request().headers
      assert Enum.count(headers, &match?({"authorization", _}, &1)) == 1
      assert {"authorization", "Bearer OVERRIDE"} in headers
    end

    test "do_delete/3 still carries query params" do
      stub_request(fn conn -> Plug.Conn.send_resp(conn, 204, "") end)
      MgmtEndpoint.delete_it("clients/1", %{force: true}, [{"Authorization", "Bearer USER"}])

      assert assert_receive_request().query == %{"force" => "true"}
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

  # Extra headers were bolted onto one verb at a time as endpoints demanded them,
  # which is how do_delete came to lack them until /mfa/authenticators needed one.
  # These assert every verb supports them, so the next gap fails here rather than
  # against a live tenant.
  describe "every verb accepts extra headers" do
    @verbs [:get, :post, :put, :patch, :delete, :delete_body, :post_form, :post_multipart]

    test "the header reaches the request" do
      for verb <- @verbs do
        stub_request(%{})
        MgmtEndpoint.with_headers(verb, "things", [{"X-Custom", "value"}])

        headers = assert_receive_request().headers
        assert {"x-custom", "value"} in headers, "#{verb} dropped the extra header"
      end
    end

    test "an extra authorization replaces the management token rather than duplicating it" do
      for verb <- @verbs do
        stub_request(%{})
        MgmtEndpoint.with_headers(verb, "things", [{"Authorization", "Bearer OVERRIDE"}])

        headers = assert_receive_request().headers

        assert Enum.count(headers, &match?({"authorization", _}, &1)) == 1,
               "#{verb} sent more than one authorization header"

        assert {"authorization", "Bearer OVERRIDE"} in headers
      end
    end
  end

  # A list body is ambiguous — keyword list meant as an object, or a genuine JSON
  # array. POST and PATCH resolve it one way and PUT the other, because that is
  # what their callers need. Unifying them would break the two array senders.
  describe "list bodies" do
    test "do_post and do_patch read a list as a keyword list, sending an object" do
      stub_request(%{})
      MgmtEndpoint.post_it("things", name: "a", value: "b")
      assert assert_receive_request().body == %{"name" => "a", "value" => "b"}

      stub_request(%{})
      MgmtEndpoint.patch_it("things/1", name: "a")
      assert assert_receive_request().body == %{"name" => "a"}
    end

    test "do_put sends a list as a JSON array" do
      stub_request(%{})
      MgmtEndpoint.put_it("things", ["all-applications"])

      body = assert_receive_request().body
      assert body == ["all-applications"]
      assert is_list(body)
    end

    test "do_put sends a list of objects as an array of objects" do
      stub_request(%{})
      MgmtEndpoint.put_it("things", [%{type: "email"}, %{type: "otp"}])

      assert assert_receive_request().body == [%{"type" => "email"}, %{"type" => "otp"}]
    end

    test "a map body is untouched by any of them" do
      for {call, verb} <- [
            {&MgmtEndpoint.post_it/2, "POST"},
            {&MgmtEndpoint.put_it/2, "PUT"},
            {&MgmtEndpoint.patch_it/2, "PATCH"}
          ] do
        stub_request(%{})
        call.("things", %{name: "a"})

        request = assert_receive_request()
        assert request.method == verb
        assert request.body == %{"name" => "a"}
      end
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
