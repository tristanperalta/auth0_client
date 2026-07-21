defmodule Auth0Client.Management.EmailProvider do
  @moduledoc """
  A module representing emails resource on Auth0
  """
  use Auth0Client.Api, for: :mgmt
  @path "emails/provider"

  @doc """
  Gets the email provider

      iex> Auth0Client.Management.EmailProvider.get()
      iex> Auth0Client.Management.EmailProvider.get(fields: "name,enabled")
  """
  def get(params \\ %{}) when is_map(params) or is_list(params) do
    do_get(@path, params)
  end

  @doc """
  Configures the email provider

  `credentials` is required — the provider's API key or SMTP details, depending on
  `name`. Without it Auth0 rejects the request.

      iex> Auth0Client.Management.EmailProvider.configure(%{
      ...>   name: "mandrill",
      ...>   enabled: true,
      ...>   credentials: %{api_key: "..."}
      ...> })
  """
  def configure(body), do: do_post(@path, body)

  @doc """
  Updates the email provider

      iex> Auth0Client.Management.EmailProvider.update(name: "new_name")
  """
  def update(body), do: do_patch(@path, body)

  @doc """
  Deletes the email provider

      iex> Auth0Client.Management.EmailProvider.delete()
  """
  def delete, do: do_delete(@path)
end
