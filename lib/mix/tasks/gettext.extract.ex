defmodule Mix.Tasks.Gettext.Extract do
  use Mix.Task
  @recursive true

  @shortdoc "Extracts translations from source code"

  @moduledoc """
  Extracts translations by recompiling the Elixir source code.

      mix gettext.extract [OPTIONS]

  Translations are extracted into POT (Portable Object Template) files (with a
  `.pot` extension). The location of these files is determined by the `:otp_app`
  and `:priv` options given by gettext modules when they call `use Gettext`. One
  POT file is generated for each translation domain.

  It is possible to give the `--merge` option to perform merging
  for every Gettext backend updated during merge:

      mix gettext.extract --merge

  All other options passed to `gettext.extract` are forwarded to the
  `gettext.merge` task (`Mix.Tasks.Gettext.Merge`), which is called internally
  by this task. For example:

      mix gettext.extract --merge --no-fuzzy

  """
  def run(args) do
    pot_files = extract()

    case args do
      [] ->
        write_extracted_files(pot_files)
      ["--merge"] ->
        write_extracted_files(pot_files)
        run_merge(pot_files, args)
      _ ->
        Mix.raise "The gettext.extract task only supports the --merge option. " <>
                  "See `mix help gettext.extract` for more information"
    end

    :ok
  end

  defp write_extracted_files(pot_files) do
    for {path, contents} <- pot_files do
      Task.async fn ->
        File.mkdir_p!(Path.dirname(path))
        File.write!(path, contents)
        Mix.shell.info "Extracted #{Path.relative_to_cwd(path)}"
      end
    end |> Enum.map(&Task.await/1)
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

  defp run_merge(pot_files, argv) do
    pot_files
    |> Enum.map(fn {path, _} -> Path.dirname(path) end)
    |> Enum.uniq
    |> Enum.map(&Task.async(fn -> Mix.Tasks.Gettext.Merge.run([&1|argv]) end))
    |> Enum.map(&Task.await/1)
  end
end
