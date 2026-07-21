defmodule Auth0Client.Management.Log do
  @moduledoc """
  A module represeting log resource on Auth0
  """
  use Auth0Client.Api, for: :mgmt
  @path "logs"

  @doc """
  Retrieve the log entries that match the specified criteria

  Auth0 caps this at 100 records per request and 1,000 results overall, so paging
  past the thousandth entry returns nothing. For more than that, use checkpoint
  pagination — pass `from` and `take` — or a log stream.

  `include_totals` is deprecated on this endpoint.

      iex> Auth0Client.Management.Log.search(page: 1, fields: "user_name")
      iex> Auth0Client.Management.Log.search(q: "type:f", take: 100)
  """
  def search(params) when is_list(params) or is_map(params) do
    do_get(@path, params)
  end

  @doc """
  Get a log event by id
  """
  def get(id) do
    do_get("#{@path}/#{id}", %{})
  end
end
