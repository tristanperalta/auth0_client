defmodule Auth0Client.Management.Job do
  @moduledoc """
  A module representing jobs on Auth0.

  Jobs are Auth0's asynchronous operations: bulk user import and export, and
  verification emails. Import and export both return a job immediately and do the
  work in the background, so the pattern is to start one, poll `get/1` until its
  status is `"completed"`, then check `errors/1`.

  https://auth0.com/docs/api/management/v2/jobs
  """

  use Auth0Client.Api, for: :mgmt
  @path "jobs"

  @doc """
  Gets a job's status.

  Poll this after starting an import or export; `status` moves through `"pending"`
  to `"completed"`, and an export adds a `location` to download from.

      iex> Auth0Client.Management.Job.get("job_abc123")
  """
  def get(id) when is_binary(id), do: do_get("#{@path}/#{id}")

  @doc """
  Gets the errors from a completed import job.

  Auth0 answers `204` when there were none, so a clean import returns a bare `:ok`
  and a partial one returns `{:ok, errors}`. Match both:

      case Auth0Client.Management.Job.errors(job_id) do
        :ok -> :no_errors
        {:ok, errors} -> handle(errors)
      end
  """
  def errors(id) when is_binary(id), do: do_get("#{@path}/#{id}/errors")

  @doc """
  Sends a verification email for the given user. `user_id` is required.

      iex> Auth0Client.Management.Job.send_verification_email(%{user_id: "auth0|123", client_id: "a_client_id"})
  """
  def send_verification_email(body) when is_map(body) do
    do_post("#{@path}/verification-email", body)
  end

  @doc """
  Starts a job exporting users from a connection.

  Returns immediately; poll `get/1` until the job carries a `location` to download.

      iex> Auth0Client.Management.Job.users_exports(%{connection_id: "con_1", format: "json"})
      iex> Auth0Client.Management.Job.users_exports(%{connection_id: "con_1", fields: [%{name: "email"}], limit: 1000})
  """
  def users_exports(body \\ %{}) when is_map(body) do
    do_post("#{@path}/users-exports", body)
  end

  @doc """
  Starts a job importing users into a connection.

  `users` is the contents of a JSON file — either a binary, or a `File.Stream` for
  something too large to hold in memory:

      iex> Auth0Client.Management.Job.users_imports(File.read!("users.json"), "con_1")
      iex> Auth0Client.Management.Job.users_imports(File.stream!("users.json"), "con_1", %{upsert: true})

  `opts` may carry `upsert`, `external_id` and `send_completion_email`. Auth0
  answers `202`; poll `get/1`, then `errors/1` to see which records failed.

  Unlike every other endpoint here, this one is `multipart/form-data` — Auth0
  accepts no other encoding for it.
  """
  def users_imports(users, connection_id, opts \\ %{}) when is_binary(connection_id) do
    fields =
      [
        users: file_part(users),
        connection_id: connection_id
      ] ++ Enum.map(opts, fn {key, value} -> {key, to_form_value(value)} end)

    do_post_multipart("#{@path}/users-imports", fields)
  end

  # A File.Stream carries its own filename and content type; a binary does not, and
  # Auth0 rejects the part without them.
  defp file_part(%File.Stream{} = stream), do: stream

  defp file_part(users) when is_binary(users) do
    {users, filename: "users.json", content_type: "application/json"}
  end

  # Req encodes binaries, iodata, integers and File.Streams. Anything else — a
  # boolean, most obviously — has no clause and raises, so coerce here rather than
  # letting `upsert: true` blow up inside the HTTP layer.
  defp to_form_value(value) when is_binary(value) or is_integer(value), do: value
  defp to_form_value(value), do: to_string(value)
end
