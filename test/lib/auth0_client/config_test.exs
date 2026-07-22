defmodule Auth0Client.ConfigTest do
  use ExUnit.Case

  alias Auth0Client.Config

  describe "domain/0" do
    setup do
      original = Application.get_env(:auth0_client, :domain)

      on_exit(fn ->
        Application.put_env(:auth0_client, :domain, original)
        Application.put_env(:auth0_client, :custom_domain, false)
      end)

      :ok
    end

    test "domain is returned" do
      assert "brighterlink.auth0.com" = Config.domain()
    end

    test "custom domain is specified" do
      Application.put_env(:auth0_client, :custom_domain, true)
      Application.put_env(:auth0_client, :domain, "auth.example.com")

      assert "auth.example.com" == Config.domain()
    end

    test "deprecated domain is specified" do
      Application.put_env(:auth0_client, :domain, "invalid")

      assert_raise(
        ArgumentError,
        ~r/the domain specified must be a fully qualified domain name/,
        fn ->
          Config.domain()
        end
      )
    end

    # config/dev.exs and the README both read the domain from System.get_env/1,
    # so an unset AUTH0_DOMAIN is the first thing a new user hits. It used to
    # raise FunctionClauseError from String.ends_with?/2, naming neither the
    # setting nor the fix.
    test "an unset domain names the setting rather than crashing in String" do
      Application.delete_env(:auth0_client, :domain)

      assert_raise ArgumentError, ~r/no :domain is configured/, fn -> Config.domain() end
    end

    # `or` evaluates left to right, so String.ends_with?(nil, _) used to raise
    # before custom_domain? was ever consulted.
    test "an unset domain reports the same with a custom domain configured" do
      Application.put_env(:auth0_client, :custom_domain, true)
      Application.delete_env(:auth0_client, :domain)

      assert_raise ArgumentError, ~r/no :domain is configured/, fn -> Config.domain() end
    end

    test "a non-binary domain is rejected as such" do
      Application.put_env(:auth0_client, :domain, :brighterlink)

      assert_raise ArgumentError, ~r/:domain must be a string/, fn -> Config.domain() end
    end
  end

  describe "mgmt_client_id/0" do
    setup do
      original = Application.get_env(:auth0_client, :mgmt_client_id)
      on_exit(fn -> Application.put_env(:auth0_client, :mgmt_client_id, original) end)
      :ok
    end

    test "returns the set value" do
      Application.put_env(:auth0_client, :mgmt_client_id, "foo")
      assert "foo" == Config.mgmt_client_id()
    end

    test "returns nil if not set" do
      Application.delete_env(:auth0_client, :mgmt_client_id)
      assert nil == Config.mgmt_client_id()
    end
  end

  describe "mgmt_client_secret/0" do
    setup do
      original = Application.get_env(:auth0_client, :mgmt_client_secret)
      on_exit(fn -> Application.put_env(:auth0_client, :mgmt_client_secret, original) end)
      :ok
    end

    test "returns the set value" do
      Application.put_env(:auth0_client, :mgmt_client_secret, "foo")
      assert "foo" == Config.mgmt_client_secret()
    end

    test "returns nil if not set" do
      Application.delete_env(:auth0_client, :mgmt_client_secret)
      assert nil == Config.mgmt_client_secret()
    end
  end

  describe "mgmt_token/0" do
    setup do
      original = Application.get_env(:auth0_client, :mgmt_token)
      on_exit(fn -> Application.put_env(:auth0_client, :mgmt_token, original) end)
      :ok
    end

    test "returns the set value" do
      Application.put_env(:auth0_client, :mgmt_token, "foo")
      assert "foo" == Config.mgmt_token()
    end

    test "returns nil if not set" do
      Application.delete_env(:auth0_client, :mgmt_token)
      assert nil == Config.mgmt_token()
    end
  end

  describe "http_opts/0" do
    setup do
      original = Application.get_env(:auth0_client, :http_opts)
      on_exit(fn -> Application.put_env(:auth0_client, :http_opts, original) end)
      :ok
    end

    test "returns the set value" do
      Application.put_env(:auth0_client, :http_opts, foo: :bar)
      assert [foo: :bar] == Config.http_opts()
    end

    test "returns an empty list if not set" do
      Application.delete_env(:auth0_client, :http_opts)
      assert [] == Config.http_opts()
    end
  end

  describe "http_opts/0 TLS verification" do
    setup do
      original = Application.get_env(:auth0_client, :http_opts)
      original_opt_in = Application.get_env(:auth0_client, :dangerously_disable_tls_verification)

      on_exit(fn ->
        Application.put_env(:auth0_client, :http_opts, original)

        case original_opt_in do
          nil ->
            Application.delete_env(:auth0_client, :dangerously_disable_tls_verification)

          value ->
            Application.put_env(:auth0_client, :dangerously_disable_tls_verification, value)
        end
      end)

      :ok
    end

    defp put_verify(verify) do
      Application.put_env(:auth0_client, :http_opts,
        connect_options: [transport_opts: [verify: verify]]
      )
    end

    test "verify_none raises" do
      put_verify(:verify_none)

      assert_raise ArgumentError, ~r/disables TLS certificate verification/, fn ->
        Config.http_opts()
      end
    end

    # An escape hatch the error never mentions is no escape hatch at all.
    test "the error names the opt-in and the correct fix" do
      put_verify(:verify_none)

      message =
        assert_raise(ArgumentError, fn -> Config.http_opts() end).message

      assert message =~ "dangerously_disable_tls_verification"
      assert message =~ "cacertfile"
    end

    test "the opt-in returns the options unchanged" do
      put_verify(:verify_none)
      Application.put_env(:auth0_client, :dangerously_disable_tls_verification, true)

      assert Config.http_opts() == [connect_options: [transport_opts: [verify: :verify_none]]]
    end

    test "a string opts in too, matching custom_domain?" do
      put_verify(:verify_none)
      Application.put_env(:auth0_client, :dangerously_disable_tls_verification, "true")

      assert Config.http_opts() == [connect_options: [transport_opts: [verify: :verify_none]]]
    end

    # cacerts/cacertfile are the right way to trust a private CA. Rejecting them would
    # push people toward the very setting this check exists to stop.
    test "trusting a private CA passes untouched" do
      for ca <- [[cacertfile: "/path/to/ca.pem"], [cacerts: [<<1, 2, 3>>]]] do
        Application.put_env(:auth0_client, :http_opts, connect_options: [transport_opts: ca])
        assert Config.http_opts() == [connect_options: [transport_opts: ca]]
      end
    end

    test "verify_peer and an absent verify both pass" do
      put_verify(:verify_peer)
      assert Config.http_opts() == [connect_options: [transport_opts: [verify: :verify_peer]]]

      Application.put_env(:auth0_client, :http_opts,
        connect_options: [transport_opts: [depth: 3]]
      )

      assert Config.http_opts() == [connect_options: [transport_opts: [depth: 3]]]
    end

    # The last of these is what config/test.exs sets, so an over-broad check would take
    # the whole suite down with it.
    test "unrelated options pass" do
      for opts <- [
            [],
            [receive_timeout: 30_000],
            [connect_options: [timeout: 10_000]],
            [plug: {Req.Test, Auth0Client.Api}, retry: false]
          ] do
        Application.put_env(:auth0_client, :http_opts, opts)
        assert Config.http_opts() == opts
      end
    end

    # Req is the right thing to complain about a malformed shape; this check only has an
    # opinion about verify_none.
    test "a malformed shape is left for Req to reject" do
      Application.put_env(:auth0_client, :http_opts, connect_options: %{transport_opts: []})
      assert Config.http_opts() == [connect_options: %{transport_opts: []}]

      Application.put_env(:auth0_client, :http_opts, "not a keyword list")
      assert Config.http_opts() == "not a keyword list"
    end
  end

  describe "warn_if_tls_verification_disabled/0" do
    setup do
      original = Application.get_env(:auth0_client, :http_opts)
      original_opt_in = Application.get_env(:auth0_client, :dangerously_disable_tls_verification)

      on_exit(fn ->
        Application.put_env(:auth0_client, :http_opts, original)

        case original_opt_in do
          nil ->
            Application.delete_env(:auth0_client, :dangerously_disable_tls_verification)

          value ->
            Application.put_env(:auth0_client, :dangerously_disable_tls_verification, value)
        end
      end)

      :ok
    end

    test "warns when verification is deliberately disabled" do
      Application.put_env(:auth0_client, :http_opts,
        connect_options: [transport_opts: [verify: :verify_none]]
      )

      Application.put_env(:auth0_client, :dangerously_disable_tls_verification, true)

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          assert :ok = Config.warn_if_tls_verification_disabled()
        end)

      assert log =~ "TLS certificate verification is DISABLED"
    end

    test "stays silent in the ordinary case" do
      Application.put_env(:auth0_client, :http_opts, receive_timeout: 30_000)

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          assert :ok = Config.warn_if_tls_verification_disabled()
        end)

      refute log =~ "TLS"
    end
  end

  describe "user_agent/0" do
    setup do
      original = Application.get_env(:auth0_client, :user_agent)
      on_exit(fn -> Application.put_env(:auth0_client, :user_agent, original) end)
      :ok
    end

    test "returns the set value" do
      Application.put_env(:auth0_client, :user_agent, "MyCustomAgent <http://example.com>")
      assert "MyCustomAgent <http://example.com>" == Config.user_agent()
    end

    test "returns the default agent if not set" do
      Application.delete_env(:auth0_client, :user_agent)
      assert "Auth0Client <https://github.com/tristanperalta/auth0_client>" == Config.user_agent()
    end
  end
end
