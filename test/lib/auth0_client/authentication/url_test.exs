defmodule Auth0Client.Authentication.UrlTest do
  use ExUnit.Case, async: true

  alias Auth0Client.Authentication.Url

  @tenant "https://brighterlink.auth0.com"

  defp query(url) do
    url |> URI.parse() |> Map.get(:query) |> Kernel.||("") |> URI.decode_query()
  end

  defp path(url), do: url |> URI.parse() |> Map.get(:path)

  # Counts on the raw URL, deliberately. query/1 goes through URI.decode_query/1,
  # which keeps only the last value per key — so a duplicated parameter is
  # invisible to it.
  defp occurrences(url, fragment), do: length(String.split(url, fragment)) - 1

  describe "authorize/2" do
    test "hangs off the tenant root" do
      url = Url.authorize("a_client_id")

      assert String.starts_with?(url, "#{@tenant}/authorize?")
      assert path(url) == "/authorize"
    end

    test "defaults response_type to code" do
      assert %{"response_type" => "code", "client_id" => "a_client_id"} =
               query(Url.authorize("a_client_id"))
    end

    test "an explicit response_type wins" do
      assert %{"response_type" => "token"} =
               query(Url.authorize("a_client_id", %{response_type: "token"}))
    end

    # authorize/2 sets client_id and response_type itself, so a caller spelling
    # either as a string key used to get both spellings encoded. Count occurrences
    # in the raw URL: URI.decode_query/1 keeps only the last value per key, so a
    # duplicate is invisible to query/1.
    test "a string-keyed response_type overrides rather than duplicating" do
      url = Url.authorize("a_client_id", %{"response_type" => "token"})

      assert occurrences(url, "response_type=") == 1
      assert query(url)["response_type"] == "token"
    end

    test "a string-keyed client_id does not duplicate, and the argument wins" do
      url = Url.authorize("a_client_id", %{"client_id" => "ignored"})

      assert occurrences(url, "client_id=") == 1
      assert query(url)["client_id"] == "a_client_id"
    end

    test "a mix of string and atom keys emits each parameter once" do
      url =
        Url.authorize("a_client_id", %{
          "response_type" => "id_token",
          :scope => "openid",
          "state" => "opaque"
        })

      assert occurrences(url, "response_type=") == 1
      assert occurrences(url, "client_id=") == 1

      assert %{
               "response_type" => "id_token",
               "client_id" => "a_client_id",
               "scope" => "openid",
               "state" => "opaque"
             } = query(url)
    end

    test "passes through the common parameters" do
      url =
        Url.authorize("a_client_id", %{
          redirect_uri: "https://app.example.com/callback",
          scope: "openid profile email",
          state: "opaque-state",
          audience: "https://api.example.com"
        })

      assert query(url) == %{
               "client_id" => "a_client_id",
               "response_type" => "code",
               "redirect_uri" => "https://app.example.com/callback",
               "scope" => "openid profile email",
               "state" => "opaque-state",
               "audience" => "https://api.example.com"
             }
    end

    test "passes through PKCE parameters without an allowlist" do
      url =
        Url.authorize("a_client_id", %{
          code_challenge: "a_challenge",
          code_challenge_method: "S256"
        })

      assert %{"code_challenge" => "a_challenge", "code_challenge_method" => "S256"} = query(url)
    end

    test "accepts a keyword list" do
      assert %{"connection" => "google-oauth2"} =
               query(Url.authorize("a_client_id", connection: "google-oauth2"))
    end

    test "escapes values that need it" do
      url = Url.authorize("a_client_id", %{redirect_uri: "https://app.example.com/cb?a=b&c=d"})

      assert query(url)["redirect_uri"] == "https://app.example.com/cb?a=b&c=d"
    end
  end

  describe "logout/1" do
    test "builds the v2 logout url" do
      url = Url.logout(%{returnTo: "https://app.example.com"})

      assert path(url) == "/v2/logout"
      assert query(url) == %{"returnTo" => "https://app.example.com"}
    end

    test "includes the client_id when given" do
      url = Url.logout(%{returnTo: "https://app.example.com", client_id: "a_client_id"})

      assert query(url)["client_id"] == "a_client_id"
    end

    test "raises without returnTo, which Auth0 requires" do
      assert_raise ArgumentError, ~r/returnTo/, fn -> Url.logout(%{}) end
      assert_raise ArgumentError, ~r/returnTo/, fn -> Url.logout(%{client_id: "a_client_id"}) end
    end

    test "accepts returnTo as a string key" do
      assert query(Url.logout(%{"returnTo" => "https://app.example.com"})) == %{
               "returnTo" => "https://app.example.com"
             }
    end

    test "emits federated as a bare flag, not federated=true" do
      url = Url.logout(%{returnTo: "https://app.example.com", federated: true})

      assert String.ends_with?(url, "&federated")
      refute url =~ "federated=true"
    end

    test "omits federated when false" do
      url = Url.logout(%{returnTo: "https://app.example.com", federated: false})

      refute url =~ "federated"
    end
  end

  describe "oidc_logout/1" do
    test "builds the oidc logout url" do
      url = Url.oidc_logout(%{id_token_hint: "an_id_token"})

      assert path(url) == "/oidc/logout"
      assert query(url) == %{"id_token_hint" => "an_id_token"}
    end

    test "requires no parameters" do
      assert Url.oidc_logout() == "#{@tenant}/oidc/logout"
    end

    test "passes through the documented parameters" do
      url =
        Url.oidc_logout(%{
          id_token_hint: "an_id_token",
          post_logout_redirect_uri: "https://app.example.com",
          client_id: "a_client_id",
          logout_hint: "a_session_id",
          state: "opaque",
          ui_locales: "en-GB fr"
        })

      assert query(url)["post_logout_redirect_uri"] == "https://app.example.com"
      assert query(url)["logout_hint"] == "a_session_id"
      assert query(url)["ui_locales"] == "en-GB fr"
    end

    test "emits federated as a bare flag" do
      url = Url.oidc_logout(%{id_token_hint: "an_id_token", federated: true})

      assert String.ends_with?(url, "&federated")
    end
  end
end
