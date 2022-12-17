defmodule Gettext.Mixfile do
  use Mix.Project

  @version "0.21.0-dev"

  @description "Internationalization and localization through gettext"
  @repo_url "https://github.com/elixir-gettext/gettext"

  def project do
    [
      app: :gettext,
      version: @version,
      elixir: "~> 1.11",
      build_embedded: Mix.env() == :prod,
      deps: deps(),
      preferred_cli_env: [docs: :docs, "coveralls.html": :test, "coveralls.github": :test],
      test_coverage: [tool: ExCoveralls],

      # Hex
      package: hex_package(),
      description: @description,

      # Docs
      name: "gettext",
      docs: [
        source_ref: "v#{@version}",
        main: "Gettext",
        source_url: @repo_url
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      env: [default_locale: "en", plural_forms: Gettext.Plural],
      mod: {Gettext.Application, []}
    ]
  end

  def hex_package do
    [
      maintainers: ["Andrea Leopardi", "José Valim"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @repo_url},
      files: ~w(lib src/gettext_po_parser.yrl mix.exs *.md)
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.19", only: :docs},
      {:excoveralls, "~> 0.15.1", only: :test},
      # TODO: Switch to stable version once ready & released
      {:expo, "~> 0.1.0-beta"}
    ]
  end
end
