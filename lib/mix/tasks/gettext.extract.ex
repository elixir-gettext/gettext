defmodule Mix.Tasks.Gettext.Extract do
  use Mix.Task
  @recursive true

  @shortdoc "Extracts translations from source code"

  @moduledoc """
  Extracts translations by recompiling the Elixir source code.

      mix gettext.extract

  Translations are extracted into POT (Portable Object Template) files (with a
  `.pot` extension). The location of these files is determined by the `:otp_app`
  and `:priv` options given by gettext modules when they call `use Gettext`. One
  POT file is generated for each translation domain.

  It is possible to give the `--merge` option to perform merging
  for every Gettext backend updated during merge:

      mix gettext.extract --merge

  """
  def run(args) do
    pot_files = extract()

    for {path, contents} <- pot_files do
      Task.async fn ->
        File.mkdir_p!(Path.dirname(path))
        File.write!(path, contents)
        Mix.shell.info "Extracted #{Path.relative_to_cwd(path)}"
      end
    end |> Enum.map(&Task.await/1)

    case args do
      [] ->
        :ok
      ["--merge"] ->
        run_merge(pot_files)
      _ ->
        Mix.raise "The gettext.extract task only supports the --merge option. " <>
                  "See `mix help gettext.extract` for more information."
    end

    :ok
  end

  defp extract do
    Gettext.Extractor.setup
    force_compile
    Gettext.Extractor.pot_files
  after
    Gettext.Extractor.teardown
  end

  defp force_compile do
    Enum.map Mix.Tasks.Compile.Elixir.manifests, &make_old_if_exists/1
    Mix.Task.run "compile"
  end

  defp make_old_if_exists(path) do
    :file.change_time(path, {{2000, 1, 1}, {0, 0, 0}})
  end

  defp run_merge(pot_files) do
    pot_files
    |> Enum.map(fn {path, _} -> Path.dirname(path) end)
    |> Enum.uniq
    |> Enum.map(&Task.async(fn -> Mix.Tasks.Gettext.Merge.run([&1]) end))
    |> Enum.map(&Task.await/1)
  end
end
