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
  def run(_args) do
    Gettext.Extractor.setup
    force_compile

    for {path, binary} <- Gettext.Extractor.dump_pot do
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, binary)
      Mix.shell.info "Extracted #{Path.relative_to_cwd(path)}"
    end

    :ok
  end

  defp force_compile do
    Enum.map Mix.Tasks.Compile.Elixir.manifests, &make_old_if_exists/1
    Mix.Task.run "compile"
  end

  defp make_old_if_exists(path) do
    :file.change_time(path, {{2000, 1, 1}, {0, 0, 0}})
  end
end
