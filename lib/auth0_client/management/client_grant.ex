defmodule Auth0Client.Management.ClientGrant do
  @moduledoc """
  A module representing client_grant resource
  """
  use Auth0Client.Api, for: :mgmt
  @path "client-grants"

  @doc """
  Gets all the client grants

      iex> Auth0Client.Management.ClientGrant.all()
      iex> Auth0Client.Management.ClientGrant.all(audience: "aud")
  """
  def all(params \\ %{}) when is_map(params) or is_list(params) do
    do_get(@path, params)
  end

  @doc """
  Gets a single client grant

      iex> Auth0Client.Management.ClientGrant.get("cgr_abc123")
  """
  def get(id) when is_binary(id), do: do_get("#{@path}/#{id}")

  @doc """
  Lists the organizations a client grant is associated with.

  Supports offset and checkpoint pagination.

      iex> Auth0Client.Management.ClientGrant.organizations("cgr_abc123")
      iex> Auth0Client.Management.ClientGrant.organizations("cgr_abc123", take: 50)
  """
  def organizations(id, params \\ %{}) when is_binary(id) do
    do_get("#{@path}/#{id}/organizations", params)
  end

  @doc """
  Creates a client grant

      iex> Auth0Client.Management.ClientGrant.create(%{client_id: "client_id", audience: "someaud", scope: []})
  """
  def create(body) do
    do_post(@path, body)
  end

  @doc """
  Updates a client grant

      iex> Auth0Client.Management.ClientGrant.update("client_grant_to_update", %{scope: []})
  """
  def update(id, body) do
    do_patch("#{@path}/#{id}", body)
  end

  @doc """
  Delete a client grant

      iex> Auth0Client.Management.ClientGrant.delete("client_grant_to_delete")
  """
  def delete(id) do
    do_delete("#{@path}/#{id}")
  end
end
