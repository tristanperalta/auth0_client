defmodule Auth0Ex.Management.JobTest do
  use ExUnit.Case, async: true
  use Auth0Ex.ReqCase

  alias Auth0Ex.Management.Job

  @job_id "job_abc123"

  defp content_type(request) do
    request.headers |> List.keyfind("content-type", 0) |> elem(1)
  end

  describe "send_verification_email/1" do
    test "posts the body to the verification-email path" do
      stub_request(%{"status" => "pending"})

      assert {:ok, %{"status" => "pending"}} =
               Job.send_verification_email(%{
                 user_id: "test_user_id",
                 client_id: "test_client_id"
               })

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/jobs/verification-email"

      assert request.body == %{
               "user_id" => "test_user_id",
               "client_id" => "test_client_id"
             }
    end
  end

  describe "get/1" do
    test "gets a job's status" do
      stub_request(%{"id" => @job_id, "status" => "completed"})

      assert {:ok, %{"status" => "completed"}} = Job.get(@job_id)

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/jobs/#{@job_id}"
    end
  end

  describe "errors/1" do
    test "returns the errors when the job had some" do
      stub_request([%{"user" => %{"email" => "bad@example.com"}, "errors" => []}])

      assert {:ok, [%{"user" => _}]} = Job.errors(@job_id)

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/jobs/#{@job_id}/errors"
    end

    # Auth0 answers 204 when the import was clean, so success is a bare :ok here
    # rather than {:ok, []} — the surprising branch, and the common one.
    test "returns :ok when the job had no errors at all" do
      stub_request(fn conn -> Plug.Conn.send_resp(conn, 204, "") end)

      assert :ok = Job.errors(@job_id)
    end
  end

  describe "users_exports/1" do
    test "starts an export as JSON" do
      stub_request(%{"id" => @job_id, "status" => "pending"})

      assert {:ok, %{"id" => @job_id}} =
               Job.users_exports(%{connection_id: "con_1", format: "json"})

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/jobs/users-exports"
      assert request.body == %{"connection_id" => "con_1", "format" => "json"}
      assert content_type(request) == "application/json"
    end

    test "defaults to an empty body" do
      stub_request(%{"id" => @job_id})

      assert {:ok, _} = Job.users_exports()

      assert assert_receive_request().body == %{}
    end
  end

  describe "users_imports/3" do
    test "posts as multipart, not JSON" do
      stub_request(fn conn ->
        conn |> Plug.Conn.put_status(202) |> Req.Test.json(%{"id" => @job_id})
      end)

      assert {:ok, %{"id" => @job_id}} =
               Job.users_imports(~s([{"email":"a@b.com"}]), "con_1")

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/jobs/users-imports"

      # The whole point of dropping the default header: Req sets this one with
      # put_new_header, so an application/json left in place would win and the
      # boundary would never be sent.
      assert content_type(request) =~ "multipart/form-data"
      assert content_type(request) =~ "boundary="
      refute content_type(request) =~ "application/json"
    end

    test "carries the file contents and connection id" do
      stub_request(fn conn -> conn |> Plug.Conn.put_status(202) |> Req.Test.json(%{}) end)

      Job.users_imports(~s([{"email":"a@b.com"}]), "con_1")

      body = assert_receive_request().body
      assert body =~ ~s([{"email":"a@b.com"}])
      assert body =~ "con_1"
      assert body =~ ~s(name="users")
      assert body =~ ~s(name="connection_id")
      assert body =~ ~s(filename="users.json")
    end

    # Req has no clause for a boolean field value and raises rather than failing
    # usefully, so booleans are coerced before they reach it.
    test "stringifies boolean options" do
      stub_request(fn conn -> conn |> Plug.Conn.put_status(202) |> Req.Test.json(%{}) end)

      assert {:ok, _} =
               Job.users_imports(~s([]), "con_1", %{upsert: true, send_completion_email: false})

      body = assert_receive_request().body
      assert body =~ ~s(name="upsert")
      assert body =~ "true"
      assert body =~ "false"
    end

    test "passes through string and integer options untouched" do
      stub_request(fn conn -> conn |> Plug.Conn.put_status(202) |> Req.Test.json(%{}) end)

      assert {:ok, _} = Job.users_imports(~s([]), "con_1", %{external_id: "ext-42"})

      assert assert_receive_request().body =~ "ext-42"
    end

    test "accepts a File.Stream for a file too large to read into memory" do
      path =
        Path.join(System.tmp_dir!(), "auth0_ex_users_#{System.unique_integer([:positive])}.json")

      File.write!(path, ~s([{"email":"streamed@example.com"}]))
      on_exit(fn -> File.rm(path) end)

      stub_request(fn conn -> conn |> Plug.Conn.put_status(202) |> Req.Test.json(%{}) end)

      assert {:ok, _} = Job.users_imports(File.stream!(path), "con_1")

      body = assert_receive_request().body
      assert body =~ "streamed@example.com"
      assert body =~ Path.basename(path)
    end
  end

  describe "authorization" do
    test "sends the configured management token" do
      stub_request(%{})

      assert {:ok, _} = Job.send_verification_email(%{user_id: "auth0|1"})

      assert {"authorization", "Bearer TESTTOKEN"} in assert_receive_request().headers
    end

    test "a multipart request still carries the management token" do
      stub_request(fn conn -> conn |> Plug.Conn.put_status(202) |> Req.Test.json(%{}) end)

      Job.users_imports(~s([]), "con_1")

      assert {"authorization", "Bearer TESTTOKEN"} in assert_receive_request().headers
    end
  end
end
