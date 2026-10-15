defmodule Mix.Tasks.Gettext.Generate do
  use Mix.Task
  @recursive true

  @shortdoc "Generates POT files from messages persisted during compilation"

  @moduledoc """
  Generates POT files without force-recompiling the project (experimental).

  ```bash
  mix gettext.generate [OPTIONS]
  ```

  Unlike `mix gettext.extract`, which force-recompiles the whole project so
  that the Gettext macros run again and re-extract the messages, this task
  generates the POT files from messages that were already extracted during the
  normal compilation. It compiles the project normally (a no-op when it is
  already compiled) and then reads the messages back from the persisted module
  attributes in the compiled BEAM files, so it avoids the cost of a
  force-recompile.

  For this to work, messages must have been persisted as module attributes
  during normal compilation. This happens automatically when the backend has
  automatic extraction enabled in the application environment, which you
  typically set in `config/dev.exs` so it stays off in `:prod`:

      # config/dev.exs
      config :gettext, MyApp.Gettext, automatic_extraction: true

  Since the attributes are only persisted when `automatic_extraction` is
  enabled (so not in `:prod`), release artifacts are unaffected.

  `automatic_extraction` is read as compile-time configuration by every
  module that uses Gettext macros (and by the backend), so toggling it
  recompiles those modules on the next `mix compile`: BEAM files compiled
  before enabling it never go unnoticed. If you had compiled the project with
  a Gettext version that predates this task, run `mix compile --force` once.

  This task accepts the same `--merge` and `--check-up-to-date` options as
  `mix gettext.extract`, and forwards any other options to
  `Mix.Tasks.Gettext.Merge`:

  ```bash
  mix gettext.generate --merge --no-fuzzy
  mix gettext.generate --check-up-to-date
  ```

  """

  @switches [merge: :boolean, check_up_to_date: :boolean]

  @impl true
  def run(args) do
    Application.ensure_all_started(:gettext)
    _ = Mix.Project.get!()
    mix_config = Mix.Project.config()
    {opts, _} = OptionParser.parse!(args, switches: @switches)
    pot_files = generate(mix_config[:app], mix_config[:gettext] || [])
    Mix.Tasks.Gettext.Extract.process(pot_files, opts, args)
  end

  defp generate(app, gettext_config) do
    compile()

    {backends, messages} =
      Gettext.Extractor.fill_from_compiled_beams(Mix.Project.compile_path())

    if backends == 0 and messages == 0 do
      Mix.raise("""
      mix gettext.generate found no persisted Gettext messages \
      or backends in #{Path.relative_to_cwd(Mix.Project.compile_path())}.

      Messages are persisted to module attributes during normal compilation only \
      when the backend has automatic extraction enabled in the application \
      environment, for example in config/dev.exs:

          config :gettext, MyApp.Gettext, automatic_extraction: true

      If you just enabled this or updated Gettext, force a recompile so that \
      up-to-date modules get their attributes written:

          mix compile --force
      """)
    end

    Gettext.Extractor.pot_files(app, gettext_config)
  end

  # The messages are extracted and persisted by the normal compilation; here we
  # just make sure that has happened, with a plain (not forced) compile.
  #
  # "compile" and the compilers it runs are regular Mix tasks, so they are
  # no-ops if they already ran in this VM (for example, through an alias such
  # as `["compile", "gettext.generate"]`, or when the task is invoked twice).
  # In that case, source files changed since that first compilation would not
  # be recompiled and we would read stale BEAM files, which is especially bad
  # for --check-up-to-date. Reenable the tasks so the compile always runs.
  defp compile do
    for task <- ~w(compile compile.all compile.elixir compile.app) do
      Mix.Task.reenable(task)
    end

    Mix.Task.run("compile", [])
  end
end
