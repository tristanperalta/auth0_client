defmodule Auth0Client.Mixfile do
  use Mix.Project

  @source_url "https://github.com/tristanperalta/auth0_client"
  @version "1.2.1"

  def project do
    [
      app: :auth0_client,
      version: @version,
      elixir: "~> 1.17",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),
      deps: deps(),
      package: package(),
      description:
        "An Elixir client for the Auth0 Management and Authentication APIs, built on Req.",
      source_url: @source_url,
      docs: docs(),
      dialyzer: [
        plt_add_apps: [:mix, :ex_unit],
        # Keyed by env so a `precommit` run (test) and CI's dialyzer job (dev)
        # do not rebuild each other's PLT.
        plt_file: {:no_warn, "priv/plts/dialyzer-#{Mix.env()}.plt"}
      ]
    ]
  end

  def cli do
    [preferred_envs: [precommit: :test]]
  end

  defp aliases do
    [
      precommit: [
        "compile --warnings-as-errors",
        "format --check-formatted",
        "deps.unlock --check-unused",
        "credo --strict --all",
        "test",
        "dialyzer"
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      mod: {Auth0Client.Application, []}
    ]
  end

  defp deps do
    [
      {:req, "~> 0.7"},
      {:jason, "~> 1.4"},
      {:plug, "~> 1.0", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.31", only: [:dev], runtime: false}
    ]
  end

  defp package do
    [
      maintainers: [
        "Tristan Peralta",
        "Samar Acharya"
      ],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md",
        "Roadmap" => "#{@source_url}/blob/main/ROADMAP.md"
      },
      # Explicit, because the default list includes priv/ — which holds the dialyzer
      # PLTs, and would ship a 4 MB build artifact in a 200 KB package.
      files: [
        "lib",
        "guides",
        "mix.exs",
        "README.md",
        "CHANGELOG.md",
        "ROADMAP.md",
        "LICENSE",
        ".formatter.exs"
      ]
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "guides/configuration.md",
        "guides/login.md",
        "guides/mfa.md",
        "guides/users.md",
        "guides/rbac.md",
        "guides/organizations.md",
        "guides/applications.md",
        "guides/connections.md",
        "guides/actions.md",
        "guides/domains-and-keys.md",
        "guides/error-handling.md",
        "CHANGELOG.md",
        "ROADMAP.md"
      ],
      groups_for_extras: [
        Guides: ~r/guides\//,
        Project: ~r/ROADMAP|CHANGELOG/
      ],
      groups_for_modules: [
        "Authentication API": [
          Auth0Client.Authentication,
          Auth0Client.Authentication.Mfa,
          Auth0Client.Authentication.Token,
          Auth0Client.Authentication.Url
        ],
        "Management API": [
          Auth0Client.Management.Action,
          Auth0Client.Management.Client,
          Auth0Client.Management.ClientGrant,
          Auth0Client.Management.Connection,
          Auth0Client.Management.Connection.DirectoryProvisioning,
          Auth0Client.Management.Connection.Scim,
          Auth0Client.Management.CustomDomain,
          Auth0Client.Management.DeviceCredential,
          Auth0Client.Management.EmailProvider,
          Auth0Client.Management.Grant,
          Auth0Client.Management.Group,
          Auth0Client.Management.Guardian,
          Auth0Client.Management.Job,
          Auth0Client.Management.Key,
          Auth0Client.Management.Log,
          Auth0Client.Management.Organization,
          Auth0Client.Management.RefreshToken,
          Auth0Client.Management.ResourceServer,
          Auth0Client.Management.Role,
          Auth0Client.Management.Session,
          Auth0Client.Management.Tenant,
          Auth0Client.Management.Ticket,
          Auth0Client.Management.User,
          Auth0Client.Management.UserBlock
        ],
        Core: [
          Auth0Client,
          Auth0Client.Config,
          Auth0Client.Error
        ],
        Internals: [
          Auth0Client.Api,
          Auth0Client.Parser,
          Auth0Client.TokenState,
          Auth0Client.Utils
        ]
      ],
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end
end
