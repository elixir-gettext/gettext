defmodule Gettext.Mixfile do
  use Mix.Project

  @version "0.16.0"

  @description "Internationalization and localization through gettext"
  @repo_url "https://github.com/elixir-lang/gettext"

  def project do
    [
      app: :gettext,
      version: @version,
      elixir: "~> 1.4",
      build_embedded: Mix.env() == :prod,
      deps: deps(),
      xref: [exclude: [{Kernel.ParallelCompiler, :async, 1}]],

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
      applications: [:logger],
      env: [default_locale: "en"],
      mod: {Gettext.Application, []}
    ]
  end

  def hex_package do
    [
      maintainers: ["Andrea Leopardi", "José Valim"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => @repo_url},
      files: ~w(lib src/gettext_po_parser.yrl mix.exs *.md)
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.19", only: :dev}
    ]
  end
end
