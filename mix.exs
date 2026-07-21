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
      extras: ["README.md"],
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end
end
