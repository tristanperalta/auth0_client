defmodule Auth0Client.Management.ResourceServer do
  @moduledoc """
  A module representing resource servers resource on Auth0
  """
  use Auth0Client.Api, for: :mgmt
  @path "resource-servers"

  @doc """
  Gets all the resource servers.

  Filter to specific APIs with `identifiers`; paginate with `page`, `per_page` and
  `include_totals`.

      iex> Auth0Client.Management.ResourceServer.all()
      iex> Auth0Client.Management.ResourceServer.all(identifiers: "https://api.example.com")
      iex> Auth0Client.Management.ResourceServer.all(page: 0, per_page: 50, include_totals: true)
  """
  def all(params \\ %{}) when is_map(params) or is_list(params) do
    do_get(@path, params)
  end

  @doc """
  Gets a resource server by ID

      iex> Auth0Client.Management.ResourceServer.get("resserver")
  """
  def get(id) do
    do_get("#{@path}/#{id}", %{})
  end

  @doc """
  Creates a resource server

      iex> Auth0Client.Management.ResourceServer.create(%{name: "resserver"})
  """
  def create(body) do
    do_post(@path, body)
  end

  @doc """
  Updates a resource server
  """
  def update(id, body) do
    do_patch("#{@path}/#{id}", body)
  end

  @doc """
  Deletes a resource server

      iex> Auth0Client.Management.ResourceServer.delete("resserver")
  """
  def delete(id) do
    do_delete("#{@path}/#{id}")
  end
end
