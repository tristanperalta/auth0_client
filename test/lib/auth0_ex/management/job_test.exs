defmodule Auth0Ex.Management.JobTest do
  use ExUnit.Case, async: true
  use Auth0Ex.ReqCase

  alias Auth0Ex.Management.Job

  describe "send_verification_email/0,1" do
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

    test "posts an empty body by default" do
      stub_request(%{"status" => "pending"})

      assert {:ok, _} = Job.send_verification_email()

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/jobs/verification-email"
      assert request.body == %{}
    end
  end

  describe "authorization" do
    test "sends the configured management token" do
      stub_request(%{})

      assert {:ok, _} = Job.send_verification_email()

      assert {"authorization", "Bearer TESTTOKEN"} in assert_receive_request().headers
    end
  end
end
