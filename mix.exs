defmodule Gettext.Mixfile do
  use Mix.Project

  @version "0.0.1"

  def project do
    [app: :gettext,
     version: @version,
     elixir: "~> 1.1-beta",
     deps: deps,

     # Docs
     name: "Gettext",
     docs: [source_ref: "v#{@version}",
            source_url: "https://github.com/elixir-lang/gettext"]]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:logger],
     env: [default_locale: "en"]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [
      {:earmark, "~> 0.1", only: :docs},
      {:ex_doc, "~> 0.7", only: :docs},
    ]
  end
end
