defmodule Gettext.Mixfile do
  use Mix.Project

  @version "0.22.0"

  @description "Internationalization and localization through gettext"
  @repo_url "https://github.com/elixir-gettext/gettext"

  def project do
    [
      app: :gettext,
      version: @version,
      elixir: "~> 1.11",
      build_embedded: Mix.env() == :prod,
      deps: deps(),
      preferred_cli_env: ["coveralls.html": :test, "coveralls.github": :test],
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
      maintainers: ["Andrea Leopardi", "Jonatan Männchen", "José Valim"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @repo_url},
      files: ~w(lib mix.exs *.md)
    ]
  end

  defp deps do
    [
      {:expo, "~> 0.3.0"},

      # Dev and test dependencies
      {:ex_doc, "~> 0.19", only: :dev},
      {:excoveralls, "~> 0.15.1", only: :test}
    ]
  end
end
