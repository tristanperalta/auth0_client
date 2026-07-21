defmodule Auth0Ex.TokenStateTest do
  # Not async: TokenState is a single named Agent started by Auth0Ex.Application,
  # so these tests share mutable global state.
  use ExUnit.Case, async: false

  alias Auth0Ex.TokenState

  setup do
    original = TokenState.get_all()

    on_exit(fn ->
      Enum.each(TokenState.get_all(), fn {key, _} -> TokenState.put(key, nil) end)
      Enum.each(original, fn {key, value} -> TokenState.put(key, value) end)
    end)

    :ok
  end

  test "get/1 returns nil for an unknown key" do
    assert nil == TokenState.get(:no_such_key)
  end

  test "put/2 then get/1 round-trips a value" do
    assert :ok = TokenState.put(:mgmt_token, "a_token")
    assert "a_token" == TokenState.get(:mgmt_token)
  end

  test "put/2 overwrites an existing value" do
    TokenState.put(:mgmt_token, "first")
    TokenState.put(:mgmt_token, "second")

    assert "second" == TokenState.get(:mgmt_token)
  end

  test "values of any type are stored as-is" do
    TokenState.put(:exp, 1_700_000_000)

    assert 1_700_000_000 == TokenState.get(:exp)
  end

  test "get_all/0 returns every stored key" do
    TokenState.put(:mgmt_token, "a_token")
    TokenState.put(:exp, 123)

    all = TokenState.get_all()

    assert %{mgmt_token: "a_token", exp: 123} = all
  end
end
