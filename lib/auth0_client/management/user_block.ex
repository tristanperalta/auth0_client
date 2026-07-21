defmodule Auth0Client.Management.UserBlock do
  @moduledoc """
  A module representing user blocks resource on Auth0
  """
  use Auth0Client.Api, for: :mgmt
  @path "user-blocks"

  @doc """
  Gets all user blocks for given identifier.
  Identifier should be any of: username, phone_number, email

  Pass `consider_brute_force_enablement: true` to have Auth0 report blocks it would
  apply given the tenant's brute-force settings, rather than only those already in
  place.

      iex> Auth0Client.Management.UserBlock.get("some@example.com")
      iex> Auth0Client.Management.UserBlock.get("some@example.com", consider_brute_force_enablement: true)
  """
  def get(identifier, params \\ %{}) when is_binary(identifier) do
    params
    |> Enum.into(%{})
    |> Map.put(:identifier, identifier)
    |> then(&do_get(@path, &1))
  end

  @doc """
  Get a user's block

  Takes `consider_brute_force_enablement` as `get/2` does.

      iex> Auth0Client.Management.UserBlock.get_user_block("auth0|234234")
      iex> Auth0Client.Management.UserBlock.get_user_block("auth0|234234", consider_brute_force_enablement: true)
  """
  def get_user_block(user_id, params \\ %{}) when is_binary(user_id) do
    do_get("#{@path}/#{user_id}", params)
  end

  @doc """
  Unblock a block by identifier

      iex> Auth0Client.Management.UserBlock.unblock("some@example.com")
  """
  def unblock(identifier), do: do_delete(@path, %{identifier: identifier})

  @doc """
  Unblock a user

      iex> Auth0Client.Management.UserBlock.unblock_user("auth0|2342")
  """
  def unblock_user(user_id), do: do_delete("#{@path}/#{user_id}")
end
