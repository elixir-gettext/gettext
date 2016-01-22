defmodule Mix.Tasks.Compile.EnsureYeccCompiler do
  def run(_args) do
    yecc? = Code.ensure_loaded?(:yecc)
    parsertools? = match?({:ok, _}, Application.ensure_all_started(:parsetools))

    unless yecc? and parsertools? do
      Mix.raise String.rstrip("""
      Could not compile :gettext because the :yecc module could not be found.
      This is likely caused by the lack of the :parsetools Erlang application.
      This may happen if your package manager broke Erlang into multiple
      packages and may be fixed by installing the missing package for Erlang.

      For example, if your package manager is apt-get:

          apt-get install erlang-parsetools

      You can find more information here:
      https://github.com/elixir-lang/gettext/issues/67.
      """, ?\n)
    end
  end
end

defmodule Gettext.Mixfile do
  use Mix.Project

  @version "0.9.0"

  @description "Internationalization and localization through gettext"
  @repo_url "https://github.com/elixir-lang/gettext"

  def project do
    [app: :gettext,
     version: @version,
     elixir: "~> 1.1-beta",
     compilers: [:ensure_yecc_compiler] ++ Mix.compilers,
     build_embedded: Mix.env == :prod,
     deps: deps,

     # Hex
     package: hex_package,
     description: @description,

     # Docs
     name: "gettext",
     docs: [source_ref: "v#{@version}", main: "Gettext",
            source_url: @repo_url]]
  end

  def application do
    [applications: [:logger],
     env: [default_locale: "en"]]
  end

  def hex_package do
    [maintainers: ["Andrea Leopardi", "José Valim"],
     licenses: ["Apache 2.0"],
     links: %{"GitHub" => @repo_url},
     files: ~w(lib src/gettext_po_parser.yrl mix.exs *.md)]
  end

  defp deps do
    [{:earmark, "~> 0.1", only: :docs},
     {:ex_doc, "~> 0.10", only: :docs}]
  end
end
