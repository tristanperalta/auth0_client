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
    Auth0Ex.TokenState.put(:mgmt_token, nil)
    Auth0Ex.TokenState.put(:exp, nil)

    on_exit(fn ->
      Application.put_env(:auth0_ex, :mgmt_token, original)
      Application.delete_env(:auth0_ex, :mgmt_client_id)
      Application.delete_env(:auth0_ex, :mgmt_client_secret)
      Auth0Ex.TokenState.put(:mgmt_token, nil)
      Auth0Ex.TokenState.put(:exp, nil)
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
