defmodule Auth0Ex.Parser do
  @moduledoc """
  Parser to parse all the responses from Auth0 API endpoints.

  Req decodes JSON response bodies automatically, so both successful and failed
  responses carry already-decoded terms. Bodies that are not JSON (an HTML error
  page, say) are passed through as the raw binary Req produced.
  """

  @type status_code :: non_neg_integer
  @type body :: map | list | binary
  @type response ::
          {:ok, body}
          | :ok
          | {:error, body, status_code}
          | {:error, %{reason: term}}

  @doc """
  Parses the response from auth0 api calls
  """
  @spec parse({:ok, Req.Response.t()} | {:error, Exception.t()}) :: response
  def parse({:ok, %Req.Response{status: status, body: body}}) when status in [200, 201] do
    {:ok, body}
  end

  def parse({:ok, %Req.Response{status: 204}}), do: :ok

  def parse({:ok, %Req.Response{status: status, body: body}}) do
    {:error, body, status}
  end

  def parse({:error, %Req.TransportError{reason: reason}}) do
    {:error, %{reason: reason}}
  end

  def parse({:error, %Req.HTTPError{reason: reason}}) do
    {:error, %{reason: reason}}
  end

  def parse({:error, exception}) when is_exception(exception) do
    {:error, %{reason: Exception.message(exception)}}
  end
end
