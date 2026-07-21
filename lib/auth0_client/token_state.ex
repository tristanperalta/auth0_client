defmodule Auth0Client.TokenState do
  @moduledoc """
  Owns the Management API token: fetching it, caching it, and renewing it.

  Only one fetch is ever in flight. Callers arriving while a fetch is running wait
  for it rather than starting their own, so a cold cache under load produces one
  request to Auth0 instead of one per caller — `/oauth/token` is rate-limited, and
  a stampede there fails every caller at once.

  Tokens are renewed shortly before they expire, by `Auth0Client.Config.token_refresh_skew/0`
  seconds, so a token cannot lapse midway through a request that is already on the wire.
  """

  use GenServer

  alias Auth0Client.Authentication.Token
  alias Auth0Client.Config
  alias Auth0Client.Error
  alias Auth0Client.Utils

  require Logger

  # Comfortably above Req's own timeouts (15s receive, 30s connect) so a slow fetch
  # resolves normally, but not :infinity — a wedged fetch has to fail its waiters
  # eventually rather than block them for the life of the VM.
  @call_timeout :timer.seconds(45)

  defstruct token: nil, exp: nil, fetching?: false, waiters: [], task_ref: nil

  @doc false
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Returns a valid Management API token, fetching one if the cache is empty or stale.
  """
  @spec fetch() :: {:ok, String.t()} | {:error, Error.t()}
  def fetch do
    GenServer.call(__MODULE__, :fetch, @call_timeout)
  catch
    :exit, {:timeout, _} -> {:error, Error.from_reason(:token_fetch_timeout)}
  end

  @doc """
  Discards the cached token, so the next `fetch/0` obtains a new one.

  Called when Auth0 rejects the token with a 401 — the secret may have rotated, or
  the client may have been revoked.
  """
  @spec invalidate() :: :ok
  def invalidate do
    GenServer.call(__MODULE__, :invalidate, @call_timeout)
  end

  @impl true
  def init(:ok), do: {:ok, %__MODULE__{}}

  @impl true
  def handle_call(:fetch, from, state) do
    cond do
      valid?(state) -> {:reply, {:ok, state.token}, state}
      state.fetching? -> {:noreply, %{state | waiters: [from | state.waiters]}}
      true -> {:noreply, start_fetch(%{state | waiters: [from]})}
    end
  end

  def handle_call(:invalidate, _from, state) do
    {:reply, :ok, %{state | token: nil, exp: nil}}
  end

  @impl true
  def handle_info({ref, result}, %{task_ref: ref} = state) do
    Process.demonitor(ref, [:flush])

    {:noreply, resolve(state, result)}
  end

  # The fetching task died. Fail everyone waiting on it rather than leaving them
  # blocked until their call timeout, and clear `fetching?` so the next caller can
  # try again.
  def handle_info({:DOWN, ref, :process, _pid, reason}, %{task_ref: ref} = state) do
    Logger.error("Auth0Client token fetch crashed: #{inspect(reason)}")

    {:noreply, resolve(state, {:error, Error.from_reason(:token_fetch_crashed)})}
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp start_fetch(state) do
    task = Task.Supervisor.async_nolink(Auth0Client.TaskSupervisor, &fetch_token/0)

    %{state | fetching?: true, task_ref: task.ref}
  end

  defp resolve(state, result) do
    reply =
      case result do
        {:ok, token, _exp} -> {:ok, token}
        {:error, _error} = error -> error
      end

    Enum.each(state.waiters, &GenServer.reply(&1, reply))

    state = %{state | fetching?: false, waiters: [], task_ref: nil}

    case result do
      {:ok, token, exp} -> %{state | token: token, exp: exp}
      _ -> state
    end
  end

  # Runs in a task, off the GenServer, so a slow fetch does not block callers
  # holding a still-valid token.
  defp fetch_token do
    client_id = Config.mgmt_client_id()
    client_secret = Config.mgmt_client_secret()
    audience = Utils.base_url(:mgmt)

    case Token.client_credentials(client_id, client_secret, audience) do
      {:ok, %{"access_token" => token}} -> with_expiry(token)
      {:ok, body} -> {:error, Error.from_reason(:missing_access_token, body: body)}
      # Never reached Auth0; the transport reason says more than :token_fetch_failed.
      {:error, %Error{status: nil} = error} -> {:error, error}
      {:error, %Error{} = error} -> {:error, %{error | reason: :token_fetch_failed}}
    end
  end

  defp with_expiry(token) do
    case exp_from_token(token) do
      {:ok, exp} -> {:ok, token, exp}
      :error -> {:error, Error.from_reason(:malformed_token)}
    end
  end

  # An Auth0 token is a JWT whose payload carries `exp`. Anything else cannot be
  # cached, since there is no way to know when it stops being valid.
  defp exp_from_token(token) do
    with [_header, payload | _] <- String.split(token, "."),
         {:ok, json} <- Base.url_decode64(payload, padding: false),
         {:ok, %{"exp" => exp}} <- Jason.decode(json) do
      {:ok, exp}
    else
      _ -> :error
    end
  end

  defp valid?(%__MODULE__{token: token, exp: exp}) when is_binary(token) and is_integer(exp) do
    exp - Config.token_refresh_skew() > System.os_time(:second)
  end

  defp valid?(%__MODULE__{}), do: false

  defimpl Inspect do
    import Inspect.Algebra

    # The struct holds a live management JWT. Keep it out of crash dumps, logs and
    # anything that inspects process state.
    def inspect(state, opts) do
      concat([
        "#Auth0Client.TokenState<",
        to_doc(
          [token: redact(state.token), exp: state.exp, fetching?: state.fetching?],
          opts
        ),
        ">"
      ])
    end

    defp redact(nil), do: nil
    defp redact(_token), do: "[REDACTED]"
  end
end
