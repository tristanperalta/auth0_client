defmodule Auth0Ex.Management.Tenant do
  @moduledoc """
  A module representing tenant settings on Auth0.

  These are the settings that apply to the whole tenant rather than to one
  application — the friendly name and logo, the default audience and directory,
  session lifetimes, and the hosted error and password-change pages.

  https://auth0.com/docs/api/management/v2/tenants
  """

  use Auth0Ex.Api, for: :mgmt
  @path "tenants/settings"

  @doc """
  Gets the tenant's settings.

  Narrow the response with `fields` and `include_fields`.

      iex> Auth0Ex.Management.Tenant.settings()
      iex> Auth0Ex.Management.Tenant.settings(fields: "friendly_name,support_email")
  """
  def settings(params \\ %{}) when is_map(params) or is_list(params) do
    do_get(@path, params)
  end

  @doc """
  Updates the tenant's settings.

  > #### This changes behaviour for every application in the tenant {: .warning}
  >
  > `default_audience`, `default_directory`, `flags` and the hosted pages affect
  > every login immediately. Read `settings/0` first and keep the result, so a
  > change can be put back.

  Only the keys you send are changed; the rest are left alone.

      iex> Auth0Ex.Management.Tenant.update_settings(%{friendly_name: "Acme"})
      iex> Auth0Ex.Management.Tenant.update_settings(%{support_email: "help@example.com"})
  """
  def update_settings(body) when is_map(body), do: do_patch(@path, body)
end
