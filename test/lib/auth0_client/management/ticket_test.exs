defmodule Auth0Client.Management.TicketTest do
  use ExUnit.Case, async: true
  use Auth0Client.ReqCase

  alias Auth0Client.Management.Ticket

  describe "email_verification/2" do
    test "posts the body with the user_id merged in" do
      stub_request(%{"ticket" => "https://example.com/ticket"})

      assert {:ok, %{"ticket" => "https://example.com/ticket"}} =
               Ticket.email_verification("auth0|user_id", %{
                 result_url: "http://myapp.com/callback",
                 ttl_sec: 0
               })

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/tickets/email-verification"

      assert request.body == %{
               "user_id" => "auth0|user_id",
               "result_url" => "http://myapp.com/callback",
               "ttl_sec" => 0
             }
    end

    test "sends only the user_id for an empty body" do
      stub_request(%{"ticket" => "https://example.com/ticket"})

      assert {:ok, _} = Ticket.email_verification("auth0|user_id", %{})

      assert assert_receive_request().body == %{"user_id" => "auth0|user_id"}
    end
  end

  describe "password_change/1" do
    test "posts the body" do
      stub_request(%{"ticket" => "https://example.com/ticket"})

      assert {:ok, %{"ticket" => "https://example.com/ticket"}} =
               Ticket.password_change(%{result_url: "http://myapp.com/callback"})

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/tickets/password-change"
      assert request.body == %{"result_url" => "http://myapp.com/callback"}
    end

    test "accepts a keyword list body" do
      stub_request(%{"ticket" => "https://example.com/ticket"})

      assert {:ok, _} = Ticket.password_change(user_id: "auth0|user_id")

      assert assert_receive_request().body == %{"user_id" => "auth0|user_id"}
    end
  end

  describe "authorization" do
    test "sends the configured management token" do
      stub_request(%{})

      assert {:ok, _} = Ticket.password_change(%{})

      assert {"authorization", "Bearer TESTTOKEN"} in assert_receive_request().headers
    end
  end
end
