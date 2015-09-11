defmodule Mix.Tasks.Gettext.Extract do
  use Mix.Task
  @recursive true

  @shortdoc "Extracts translations from source code"

  @doc """
  Extracts translations by recompiling the Elixir source code.

      mix gettext.extract

  It is possible to give the `--merge` option to perform merging
  for every Gettext backend updated during merge:

      mix gettext.extract --merge

  """
  def run(args) do
    changed =
      extract
      |> write_changed_files()
      |> print_changed_files()

    case args do
      [] ->
        :ok
      ["--merge"] ->
        run_merge(changed)
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

  defp write_changed_files(pot_files) do
    Enum.flat_map pot_files, fn {path, contents} ->
      File.mkdir_p! Path.dirname(path)

      # Write the file only if it doesn't exist or the contents wouldn't change.
      if not File.regular?(path) or File.read!(path) != IO.iodata_to_binary(contents) do
        File.write!(path, contents)
        [path]
      else
        []
      end
    end
  end

  defp print_changed_files(files) do
    Enum.each files, fn f -> Mix.shell.info("Extracted #{Path.relative_to_cwd(f)}") end
    files
  end

  defp run_merge(changed_pot_files) do
    changed_pot_files
    |> Enum.group_by(&Path.dirname/1)
    |> Map.keys
    |> Enum.each(fn priv -> Mix.Task.run("gettext.merge", [priv]) end)
  end
end
