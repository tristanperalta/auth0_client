defmodule Auth0Client.Error do
  @moduledoc """
  The single failure value returned by every `Auth0Client` function.

  Auth0 can fail in three unrelated ways — it answers with an error status, the
  request never reaches it, or no management token can be obtained — and all three
  arrive here as one struct, so a caller needs one clause rather than three:

      case Auth0Client.Management.User.get(id) do
        {:ok, user} -> user
        {:error, %Auth0Client.Error{reason: :not_found}} -> nil
        {:error, %Auth0Client.Error{} = error} -> raise error
      end

  It is an exception, so `raise error` works when a caller would rather not handle
  the failure at all.
  """

  defexception [:reason, :status, :body, :headers]

  @type t :: %__MODULE__{
          reason: atom,
          status: non_neg_integer | nil,
          body: term,
          headers: %{optional(binary) => [binary]}
        }

  @doc """
  Builds an error from an HTTP response Auth0 rejected.

  `reason` is derived from the status so callers can match on meaning rather than
  on numbers.
  """
  @spec from_response(non_neg_integer, term, map) :: t
  def from_response(status, body, headers) do
    %__MODULE__{reason: reason_for_status(status), status: status, body: body, headers: headers}
  end

  @doc """
  Builds an error for a failure that produced no HTTP response — a transport
  problem, or a management token that could not be obtained.
  """
  @spec from_reason(atom, keyword) :: t
  def from_reason(reason, opts \\ []) do
    %__MODULE__{
      reason: reason,
      status: Keyword.get(opts, :status),
      body: Keyword.get(opts, :body),
      headers: Keyword.get(opts, :headers, %{})
    }
  end

  @doc """
  The `Retry-After` delay in seconds, or `nil` when the header is absent or is not
  a plain number.

  Auth0 sends this on a 429. Honour it rather than guessing a backoff:

      {:error, %Auth0Client.Error{reason: :rate_limited} = error} ->
        Process.sleep((Auth0Client.Error.retry_after(error) || 1) * 1000)

  The HTTP-date form of `Retry-After` is not parsed; Auth0 sends seconds.
  """
  @spec retry_after(t) :: non_neg_integer | nil
  def retry_after(%__MODULE__{headers: headers}) when is_map(headers) do
    case Map.get(headers, "retry-after") do
      [value | _] -> parse_seconds(value)
      value when is_binary(value) -> parse_seconds(value)
      _ -> nil
    end
  end

  def retry_after(%__MODULE__{}), do: nil

  @impl true
  def message(%__MODULE__{reason: reason, status: nil}) do
    "auth0 request failed: #{reason}"
  end

  def message(%__MODULE__{reason: reason, status: status, body: body}) do
    "auth0 request failed: #{reason} (HTTP #{status}) — #{describe(body)}"
  end

  defp parse_seconds(value) do
    case Integer.parse(value) do
      {seconds, ""} when seconds >= 0 -> seconds
      _ -> nil
    end
  end

  defp describe(%{"error_description" => description}), do: description
  defp describe(%{"message" => message}), do: message
  defp describe(%{"error" => error}), do: error
  defp describe(body) when is_binary(body), do: body
  defp describe(body), do: inspect(body)

  defp reason_for_status(400), do: :bad_request
  defp reason_for_status(401), do: :unauthorized
  defp reason_for_status(403), do: :forbidden
  defp reason_for_status(404), do: :not_found
  defp reason_for_status(409), do: :conflict
  defp reason_for_status(429), do: :rate_limited
  defp reason_for_status(status) when status >= 500, do: :server_error
  defp reason_for_status(_status), do: :http_error
end
