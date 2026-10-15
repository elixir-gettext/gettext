defmodule Mix.Tasks.Gettext.Generate do
  use Mix.Task

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
  before enabling it never go unnoticed. For the same reason it must be set in
  the compile-time configuration files (such as `config/config.exs` or
  `config/dev.exs`), not in `config/runtime.exs`. If you had compiled the
  project with a Gettext version that predates this task, run
  `mix compile --force` once.

  In an umbrella project, the task compiles all the applications and loads the
  messages of all of them before generating the POT files of each application,
  like `mix gettext.extract` does, so a backend can be shared between
  applications.

  The generated POT files are the same as the ones `mix gettext.extract`
  generates, with two differences. Messages are persisted in the module being
  compiled, so calls to the Gettext macros outside of a module (at the top
  level of a file) are not extracted. The extracted comments of a message that
  appears in several modules with different comments are listed in the order
  in which the modules are read back, which can differ from the order in which
  they were compiled.

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
    {opts, _} = OptionParser.parse!(args, switches: @switches)

    compile()

    if Mix.Project.umbrella?() do
      apps_paths = Mix.Project.apps_paths()

      # Applications may share a backend, so all the messages must be loaded
      # before any application's POT files are generated. Each application is
      # read from its own directory so that the references in the POT files
      # are relative to it, as with mix gettext.extract.
      apps_paths
      |> Enum.map(fn {app, path} -> in_app(app, path, &fill_from_compiled_beams/0) end)
      |> check_found!()

      for {app, path} <- apps_paths do
        in_app(app, path, fn -> generate(app, opts, args) end)
      end
    else
      check_found!([fill_from_compiled_beams()])
      generate(Mix.Project.config()[:app], opts, args)
    end

    :ok
  end

  # Runs `fun` inside the given umbrella application, with the configuration
  # the umbrella passes down to its applications (such as the shared build
  # path), as Mix itself does when running recursive tasks.
  defp in_app(app, path, fun) do
    config = Keyword.delete(Mix.Project.deps_config(), :deps_path)
    Mix.Project.in_project(app, path, config, fn _module -> fun.() end)
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
    reenable_compilers()

    for task <- ~w(compile.protocols compile.all compile) do
      Mix.Task.reenable(task)
    end

    Mix.Task.run("compile", [])
  end

  # Mix tracks whether a task ran per project, and each application of an
  # umbrella may configure its own compilers, so reenable them from within
  # each application.
  defp reenable_compilers do
    if Mix.Project.umbrella?() do
      for {app, path} <- Mix.Project.apps_paths() do
        in_app(app, path, &reenable_project_compilers/0)
      end
    else
      reenable_project_compilers()
    end

    :ok
  end

  defp reenable_project_compilers do
    for compiler <- Mix.Project.config()[:compilers] || Mix.compilers() do
      Mix.Task.reenable("compile.#{compiler}")
    end
  end

  defp fill_from_compiled_beams do
    compile_path = Mix.Project.compile_path()
    {backends, messages} = Gettext.Extractor.fill_from_compiled_beams(compile_path)
    {compile_path, backends, messages}
  end

  defp check_found!(results) do
    compile_paths = for {compile_path, _backends, _messages} <- results, do: compile_path

    {backends, messages} =
      Enum.reduce(results, {0, 0}, fn {_path, backends, messages}, {backends_acc, messages_acc} ->
        {backends_acc + backends, messages_acc + messages}
      end)

    if backends == 0 and messages == 0 do
      Mix.raise("""
      mix gettext.generate found no persisted Gettext messages or backends in:

      #{Enum.map_join(compile_paths, "\n", &"  * #{Path.relative_to_cwd(&1)}")}

      Messages are persisted to module attributes during normal compilation only \
      when the backend has automatic extraction enabled in the application \
      environment, for example in config/dev.exs:

          config :gettext, MyApp.Gettext, automatic_extraction: true

      If you just enabled this or updated Gettext, force a recompile so that \
      up-to-date modules get their attributes written:

          mix compile --force
      """)
    end

    :ok
  end

  defp generate(app, opts, args) do
    gettext_config = Mix.Project.config()[:gettext] || []
    pot_files = Gettext.Extractor.pot_files(app, gettext_config)
    Mix.Tasks.Gettext.Extract.process(pot_files, opts, args, "gettext.generate")
  end
end
