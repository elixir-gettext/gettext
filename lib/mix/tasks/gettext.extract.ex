defmodule Mix.Tasks.Gettext.Extract do
  use Mix.Task
  @recursive true

  @shortdoc "Extracts translations"

  @doc """
  Extracts translations by recompiling the Elixir source code.
  """
  def run(_args) do
    Gettext.Extractor.setup
    force_compile

    for {path, binary} <- Gettext.Extractor.pot_files do
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, binary)
      Mix.shell.info "Extracted #{Path.relative_to_cwd(path)}"
    end

    Gettext.Extractor.teardown
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
