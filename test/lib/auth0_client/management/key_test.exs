defmodule Auth0Client.Management.KeyTest do
  use ExUnit.Case, async: true
  use Auth0Client.ReqCase

  alias Auth0Client.Management.Key

  @kid "abc123"

  describe "application signing keys" do
    test "signing_keys/0 lists them" do
      stub_request([%{"kid" => @kid, "current" => true}])

      assert {:ok, [%{"kid" => @kid}]} = Key.signing_keys()

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/keys/signing"
    end

    test "signing_key/1 gets one by kid" do
      stub_request(%{"kid" => @kid})

      assert {:ok, %{"kid" => @kid}} = Key.signing_key(@kid)

      assert assert_receive_request().path == "/api/v2/keys/signing/#{@kid}"
    end

    test "rotate_signing_key/0 posts to the rotate path" do
      stub_request(%{"kid" => "new_kid"})

      assert {:ok, %{"kid" => "new_kid"}} = Key.rotate_signing_key()

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/keys/signing/rotate"
    end

    # Auth0 uses PUT here, where every other revoke-shaped call in this library is
    # a POST or DELETE. Getting it wrong would fail only against a live tenant.
    test "revoke_signing_key/1 uses PUT, not POST or DELETE" do
      stub_request(%{"kid" => @kid})

      assert {:ok, _} = Key.revoke_signing_key(@kid)

      request = assert_receive_request()
      assert request.method == "PUT"
      assert request.path == "/api/v2/keys/signing/#{@kid}/revoke"
    end
  end

  describe "encryption keys" do
    test "encryption_keys/1 lists them" do
      stub_request([%{"kid" => @kid, "type" => "tenant-encryption-key"}])

      assert {:ok, [%{"kid" => @kid}]} = Key.encryption_keys()

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/keys/encryption"
    end

    test "encryption_keys/1 paginates" do
      stub_request([])
      Key.encryption_keys(per_page: 50, include_totals: true)

      assert assert_receive_request().query == %{
               "per_page" => "50",
               "include_totals" => "true"
             }
    end

    test "encryption_key/1 gets one by kid" do
      stub_request(%{"kid" => @kid})

      assert {:ok, _} = Key.encryption_key(@kid)

      assert assert_receive_request().path == "/api/v2/keys/encryption/#{@kid}"
    end

    test "create_encryption_key/1 posts the type" do
      stub_request(%{"kid" => "new_kid"})

      assert {:ok, _} = Key.create_encryption_key(%{type: "tenant-encryption-key"})

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/keys/encryption"
      assert request.body == %{"type" => "tenant-encryption-key"}
    end

    test "create_wrapping_key/1 posts to the wrapping-key path" do
      stub_request(%{"public_key" => "..."})

      assert {:ok, _} = Key.create_wrapping_key(@kid)

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/keys/encryption/#{@kid}/wrapping-key"
    end

    test "import_encryption_key/2 wraps the material under wrapped_key" do
      stub_request(%{"kid" => @kid})

      assert {:ok, _} = Key.import_encryption_key(@kid, "base64-material")

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/keys/encryption/#{@kid}"
      assert request.body == %{"wrapped_key" => "base64-material"}
    end

    test "delete_encryption_key/1 deletes by kid" do
      stub_status(204)

      assert :ok = Key.delete_encryption_key(@kid)

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/keys/encryption/#{@kid}"
    end

    test "rekey/0 posts to the rekey path" do
      stub_status(204)

      assert :ok = Key.rekey()

      request = assert_receive_request()
      assert request.method == "POST"
      assert request.path == "/api/v2/keys/encryption/rekey"
    end
  end

  describe "custom signing keys" do
    test "custom_signing_keys/0 reads them" do
      stub_request(%{"keys" => []})

      assert {:ok, %{"keys" => []}} = Key.custom_signing_keys()

      request = assert_receive_request()
      assert request.method == "GET"
      assert request.path == "/api/v2/keys/custom-signing"
    end

    test "replace_custom_signing_keys/1 wraps the list under keys" do
      stub_request(%{"keys" => []})

      assert {:ok, _} =
               Key.replace_custom_signing_keys([%{kty: "RSA", kid: "abc", use: "sig"}])

      request = assert_receive_request()
      assert request.method == "PUT"
      assert request.path == "/api/v2/keys/custom-signing"

      assert request.body == %{
               "keys" => [%{"kty" => "RSA", "kid" => "abc", "use" => "sig"}]
             }
    end

    test "replace_custom_signing_keys/1 does not send a bare array" do
      stub_request(%{})
      Key.replace_custom_signing_keys([%{kid: "abc"}])

      body = assert_receive_request().body
      refute is_list(body)
      assert is_map(body)
    end

    test "delete_custom_signing_keys/0 removes them" do
      stub_status(204)

      assert :ok = Key.delete_custom_signing_keys()

      request = assert_receive_request()
      assert request.method == "DELETE"
      assert request.path == "/api/v2/keys/custom-signing"
    end
  end

  # Three unrelated key families under one prefix — a copy-paste between them
  # would be invisible in review.
  describe "the three families use three distinct paths" do
    test "signing, encryption and custom-signing do not overlap" do
      stub_request(%{})
      Key.signing_keys()
      signing = assert_receive_request().path

      stub_request(%{})
      Key.encryption_keys()
      encryption = assert_receive_request().path

      stub_request(%{})
      Key.custom_signing_keys()
      custom = assert_receive_request().path

      assert signing == "/api/v2/keys/signing"
      assert encryption == "/api/v2/keys/encryption"
      assert custom == "/api/v2/keys/custom-signing"
      assert Enum.uniq([signing, encryption, custom]) == [signing, encryption, custom]
    end
  end

  describe "authorization" do
    test "sends the management token" do
      stub_request([])
      Key.signing_keys()

      assert {"authorization", "Bearer TESTTOKEN"} in assert_receive_request().headers
    end
  end
end
