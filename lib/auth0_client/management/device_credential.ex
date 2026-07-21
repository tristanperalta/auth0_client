defmodule Auth0Client.Management.DeviceCredential do
  @moduledoc """
  A module representing device credential resource on Auth0
  """
  use Auth0Client.Api, for: :mgmt
  @path "device-credentials"

  @doc """
  Gets all the device credentials

      iex> Auth0Client.Management.DeviceCredential.all()
      iex> Auth0Client.Management.DeviceCredential.all(fields: "id,device_name")
  """
  def all(params \\ %{}) when is_map(params) or is_list(params) do
    do_get(@path, params)
  end

  @doc """
  Creates a device public key

      iex> Auth0Client.Management.DeviceCredential.create(%{device_name: "adev"})
  """
  def create(body) do
    do_post(@path, body)
  end

  @doc """
  Deletes a device credential

      iex> Auth0Client.Management.DeviceCredential.delete("device_credential")
  """
  def delete(id) do
    do_delete("#{@path}/#{id}")
  end
end
