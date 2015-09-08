defmodule Mix.Tasks.Gettext.Extract do
  use Mix.Task
  @recursive true

  @shortdoc "Extracts translations"

  def run(_args) do
    Mix.shell.info "About to extract Gettext translation from source. Recompiling..."

    Gettext.Extractor.setup_for_extraction
    force_compile
    Gettext.Extractor.process_results
  end

  defp force_compile do
    Enum.each ~w(compile compile.all compile.elixir), &Mix.Task.reenable/1
    Mix.Task.run "compile", ["--force"]
  end
end
