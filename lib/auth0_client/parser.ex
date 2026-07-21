defmodule Auth0Client.Parser do
  @moduledoc """
  Parser to parse all the responses from Auth0 API endpoints.

  Req decodes JSON response bodies automatically, so a successful response carries
  an already-decoded term. Bodies that are not JSON — an HTML error page, say — are
  passed through as the raw binary Req produced.

  Every failure becomes an `Auth0Client.Error`, which carries the response headers so
  callers can honour `Retry-After` on a 429.
  """

  alias Auth0Client.Error

  @type status_code :: non_neg_integer
  @type body :: map | list | binary
  @type response :: {:ok, body} | :ok | {:error, Error.t()}

  @doc """
  Parses the response from auth0 api calls
  """
  @spec parse({:ok, Req.Response.t()} | {:error, Exception.t()}) :: response
  # Auth0 answers a mutation that returns nothing with 200, 201 or 204 depending on
  # the endpoint. They mean the same thing, so they get the same value here rather
  # than leaving callers with a meaningless {:ok, ""}.
  def parse({:ok, %Req.Response{status: status, body: body}})
      when status in 200..299 and body in ["", nil] do
    :ok
  end

  # Any 2xx, not just 200 and 201 — Auth0 answers an accepted-but-asynchronous
  # operation with 202, and deploying an action is one.
  def parse({:ok, %Req.Response{status: status, body: body}}) when status in 200..299 do
    {:ok, body}
  end

  def parse({:ok, %Req.Response{status: status, body: body, headers: headers}}) do
    {:error, Error.from_response(status, body, headers)}
  end

  def parse({:error, %Req.TransportError{reason: reason}}) do
    {:error, Error.from_reason(reason)}
  end

  def parse({:error, %Req.HTTPError{reason: reason}}) do
    {:error, Error.from_reason(reason)}
  end

  def parse({:error, %Error{} = error}), do: {:error, error}

  def parse({:error, exception}) when is_exception(exception) do
    {:error, Error.from_reason(:request_failed, body: Exception.message(exception))}
  end
end
