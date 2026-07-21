defmodule Auth0Ex.ApiTokenFailureTest do
  @moduledoc """
  Covers the path where a management call cannot even build its headers, because
  fetching the management token failed.

  Not async: these tests clear the statically configured `:mgmt_token`, which every
  other management test reads.
  """
  use ExUnit.Case, async: false
  use Auth0Ex.ReqCase

  defmodule MgmtEndpoint do
    @moduledoc false
    use Auth0Ex.Api, for: :mgmt

    def get_it(path, params \\ %{}), do: do_get(path, params)
  end

  setup do
    original = Application.get_env(:auth0_ex, :mgmt_token)

    Application.delete_env(:auth0_ex, :mgmt_token)
    Application.put_env(:auth0_ex, :mgmt_client_id, "a_client_id")
    Application.put_env(:auth0_ex, :mgmt_client_secret, "a_client_secret")
    Auth0Ex.TokenState.invalidate()

    on_exit(fn ->
      Application.put_env(:auth0_ex, :mgmt_token, original)
      Application.delete_env(:auth0_ex, :mgmt_client_id)
      Application.delete_env(:auth0_ex, :mgmt_client_secret)
      Auth0Ex.TokenState.invalidate()
    end)

    :ok
  end

  test "a rate-limited token fetch returns an error tuple instead of raising" do
    Req.Test.stub(Auth0Ex.Api, fn conn ->
      conn |> Plug.Conn.put_status(429) |> Req.Test.json(%{"error" => "too_many_requests"})
    end)

    assert {:error, %{reason: :token_fetch_failed, status: 429}} = MgmtEndpoint.get_it("clients")
  end

  test "rejected credentials return an error tuple" do
    Req.Test.stub(Auth0Ex.Api, fn conn ->
      conn |> Plug.Conn.put_status(401) |> Req.Test.json(%{"error" => "access_denied"})
    end)

    assert {:error, %{reason: :token_fetch_failed, status: 401}} = MgmtEndpoint.get_it("clients")
  end

  test "a transport failure fetching the token returns an error tuple" do
    Req.Test.stub(Auth0Ex.Api, fn conn ->
      Req.Test.transport_error(conn, :econnrefused)
    end)

    assert {:error, %{reason: :econnrefused}} = MgmtEndpoint.get_it("clients")
  end

  describe "a 401 on a management call" do
    # Routes by path and counts management attempts, so one stub can express
    # "reject the first call, accept the replay".
    defp stub_rejecting_first_call(token_fun) do
      {:ok, attempts} = Agent.start_link(fn -> 0 end)
      test_pid = self()

      Req.Test.stub(Auth0Ex.Api, fn conn ->
        case conn.request_path do
          "/oauth/token" ->
            send(test_pid, :token_request)
            Req.Test.json(conn, %{"access_token" => token_fun.()})

          _ ->
            attempt = Agent.get_and_update(attempts, &{&1 + 1, &1 + 1})
            send(test_pid, {:mgmt_request, attempt})
            management_response(conn, attempt)
        end
      end)
    end

    defp management_response(conn, 1) do
      conn |> Plug.Conn.put_status(401) |> Req.Test.json(%{"error" => "Unauthorized"})
    end

    defp management_response(conn, _attempt) do
      Req.Test.json(conn, [%{"name" => "an_app"}])
    end

    test "refreshes the token and replays the request once" do
      stub_rejecting_first_call(fn -> build_jwt(unix_from_now(3600)) end)

      assert {:ok, [%{"name" => "an_app"}]} = MgmtEndpoint.get_it("clients")

      # Two management attempts: the rejected one and the replay.
      assert_receive {:mgmt_request, 1}
      assert_receive {:mgmt_request, 2}
      refute_receive {:mgmt_request, 3}

      # Two token fetches: the initial one, and one after the 401 evicted it.
      assert_receive :token_request
      assert_receive :token_request
    end

    test "gives up after one retry rather than looping" do
      test_pid = self()

      Req.Test.stub(Auth0Ex.Api, fn conn ->
        case conn.request_path do
          "/oauth/token" ->
            Req.Test.json(conn, %{"access_token" => build_jwt(unix_from_now(3600))})

          _ ->
            send(test_pid, :mgmt_request)
            conn |> Plug.Conn.put_status(401) |> Req.Test.json(%{"error" => "Unauthorized"})
        end
      end)

      assert {:error, %Auth0Ex.Error{status: 401}} = MgmtEndpoint.get_it("clients")

      assert_receive :mgmt_request
      assert_receive :mgmt_request
      refute_receive :mgmt_request, 100
    end

    test "is not retried when the token is statically configured" do
      Application.put_env(:auth0_ex, :mgmt_token, "STATIC")
      test_pid = self()

      Req.Test.stub(Auth0Ex.Api, fn conn ->
        send(test_pid, :mgmt_request)
        conn |> Plug.Conn.put_status(401) |> Req.Test.json(%{"error" => "Unauthorized"})
      end)

      assert {:error, %Auth0Ex.Error{status: 401}} = MgmtEndpoint.get_it("clients")

      # Nothing to refresh, so no second attempt.
      assert_receive :mgmt_request
      refute_receive :mgmt_request, 100
    end

    test "a 403 is not retried" do
      test_pid = self()

      Req.Test.stub(Auth0Ex.Api, fn conn ->
        case conn.request_path do
          "/oauth/token" ->
            Req.Test.json(conn, %{"access_token" => build_jwt(unix_from_now(3600))})

          _ ->
            send(test_pid, :mgmt_request)
            conn |> Plug.Conn.put_status(403) |> Req.Test.json(%{"error" => "Forbidden"})
        end
      end)

      assert {:error, %Auth0Ex.Error{reason: :forbidden}} = MgmtEndpoint.get_it("clients")

      assert_receive :mgmt_request
      refute_receive :mgmt_request, 100
    end
  end

  test "the management endpoint itself is never called" do
    test_pid = self()

    Req.Test.stub(Auth0Ex.Api, fn conn ->
      send(test_pid, {:path, conn.request_path})
      conn |> Plug.Conn.put_status(401) |> Req.Test.json(%{"error" => "access_denied"})
    end)

    assert {:error, _} = MgmtEndpoint.get_it("clients")

    assert_receive {:path, "/oauth/token"}
    refute_receive {:path, "/api/v2/clients"}
  end
end
