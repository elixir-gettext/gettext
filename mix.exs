defmodule Gettext.Mixfile do
  use Mix.Project

  @version "0.18.2"

  @description "Internationalization and localization through gettext"
  @repo_url "https://github.com/elixir-gettext/gettext"

  def project do
    [
      app: :gettext,
      version: @version,
      elixir: "~> 1.6",
      build_embedded: Mix.env() == :prod,
      deps: deps(),

      # Hex
      package: hex_package(),
      description: @description,

      # Docs
      name: "gettext",
      docs: [
        source_ref: "v#{@version}",
        main: "Gettext",
        source_url: @repo_url,
        extras: ["CHANGELOG.md"],
        skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
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
      files: ~w(lib src/gettext_po_parser.yrl mix.exs *.md),
      links: %{
        "Changelog" => "https://hexdocs.pm/gettext/changelog.html",
        "GitHub" => @repo_url
      }
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.19", only: :docs}
    ]
  end
end
