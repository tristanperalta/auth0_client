defmodule Auth0Ex.Mixfile do
  use Mix.Project

  @source_url "https://github.com/tristanperalta/auth0_client"
  @version "0.9.0"

  def project do
    [
      app: :auth0_ex,
      version: @version,
      elixir: "~> 1.17",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),
      deps: deps(),
      package: package(),
      description: "An elixir client library for Auth0",
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
      mod: {Auth0Ex.Application, []}
    ]
  end

  defp deps do
    [
      {:req, "~> 0.6"},
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
      links: %{"GitHub" => @source_url}
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
        "ROADMAP.md"
      ],
      groups_for_extras: [
        Guides: ~r/guides\//,
        Project: ~r/ROADMAP/
      ],
      groups_for_modules: [
        "Authentication API": [
          Auth0Ex.Authentication,
          Auth0Ex.Authentication.Mfa,
          Auth0Ex.Authentication.Token,
          Auth0Ex.Authentication.Url
        ],
        "Management API": [
          Auth0Ex.Management.Action,
          Auth0Ex.Management.Client,
          Auth0Ex.Management.ClientGrant,
          Auth0Ex.Management.Connection,
          Auth0Ex.Management.Connection.DirectoryProvisioning,
          Auth0Ex.Management.Connection.Scim,
          Auth0Ex.Management.CustomDomain,
          Auth0Ex.Management.DeviceCredential,
          Auth0Ex.Management.EmailProvider,
          Auth0Ex.Management.Grant,
          Auth0Ex.Management.Guardian,
          Auth0Ex.Management.Job,
          Auth0Ex.Management.Key,
          Auth0Ex.Management.Log,
          Auth0Ex.Management.Organization,
          Auth0Ex.Management.ResourceServer,
          Auth0Ex.Management.Role,
          Auth0Ex.Management.Tenant,
          Auth0Ex.Management.Ticket,
          Auth0Ex.Management.User,
          Auth0Ex.Management.UserBlock
        ],
        Core: [
          Auth0Ex,
          Auth0Ex.Config,
          Auth0Ex.Error
        ],
        Internals: [
          Auth0Ex.Api,
          Auth0Ex.Parser,
          Auth0Ex.TokenState,
          Auth0Ex.Utils
        ]
      ],
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end
end
