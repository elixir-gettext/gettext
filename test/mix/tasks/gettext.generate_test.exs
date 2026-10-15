defmodule Mix.Tasks.Gettext.GenerateTest do
  # async: false (default) is required: these tests mutate global Mix task
  # invocation state, the code path, and Code.compiler_options/1.
  use ExUnit.Case

  import ExUnit.CaptureIO
  import GettextTest.MixProjectHelpers

  @moduletag :tmp_dir

  @fixture_modules [
    MyApp.Gettext,
    MyApp,
    MyApp.Labels,
    MyApp.Consumer,
    MyApp.Other,
    MyApp.WithBackend,
    MyApp.Legacy,
    AppOne.Gettext,
    AppOne,
    AppTwo.Gettext,
    AppTwo
  ]

  setup_all do
    # To suppress the `redefining module MyApp` warnings for the test modules
    previous = Code.compiler_options()[:ignore_module_conflict]
    Code.compiler_options(ignore_module_conflict: true)
    on_exit(fn -> Code.compiler_options(ignore_module_conflict: previous) end)
    :ok
  end

  setup do
    # Loaded fixture modules are global to the test VM; unload them so that
    # each test resolves backends against its own modules. (Mix task
    # invocation state needs no reset: the task reenables the compile tasks
    # itself, which is what makes it work in the first place.)
    #
    # Fully unload fixture modules: with lazy module loading (Elixir 1.19+),
    # a stale MyApp.Gettext loaded by a previous test would otherwise keep
    # answering __gettext__/1 with the previous test's configuration.
    for module <- @fixture_modules do
      :code.purge(module)
      :code.delete(module)
      :code.purge(module)
    end

    # Also drop previous test projects' ebin dirs from the code path
    # (in_project is called with prune_code_paths: false), so that the
    # unloaded fixture modules cannot be lazily re-loaded from a previous
    # test's _build. Must run OUTSIDE in_project: it relies on File.cwd!()
    # being the repo root.
    tmp_root = Path.join(File.cwd!(), "tmp")

    for path <- :code.get_path(),
        path_string = List.to_string(path),
        String.starts_with?(path_string, tmp_root) do
      :code.del_path(path)
    end

    # Drain extractor state left behind by other test files (their fixture
    # projects use the same MyApp.Gettext module name, so leftover messages
    # would be popped into this test's POT files). Reset the full initial
    # state, including extracting?, in case a previous test died between
    # enable() and disable().
    Agent.update(Gettext.ExtractorAgent, fn _state ->
      %{messages: %{}, backends: [], extracting?: false}
    end)

    # Messages are only persisted for backends with automatic_extraction
    # enabled in the application environment. Enable it for the fixture
    # backend by default; the "disabled" test below clears it.
    Application.put_env(:gettext, MyApp.Gettext, automatic_extraction: true)
    on_exit(fn -> Application.delete_env(:gettext, MyApp.Gettext) end)

    :ok
  end

  @fixture_source """
  defmodule MyApp.Gettext do
    use Gettext.Backend, otp_app: %APP%
  end

  defmodule MyApp do
    use Gettext, backend: MyApp.Gettext

    def singular(), do: gettext("hello")
    def with_domain(), do: dgettext("my_domain", "domain hello")
    def with_context(), do: pgettext("a context", "ctx hello")

    def plural(n), do: ngettext("one item", "%{count} items", n)

    gettext_comment("a comment for translators")
    def with_comment(), do: gettext("commented hello")

    def noop(), do: gettext_noop("noop hello")
  end
  """

  defp write_fixture(context) do
    source = String.replace(@fixture_source, "%APP%", inspect(context.test))
    write_file(context, "lib/my_app.ex", source)
  end

  test "extracts the same POT files as the recompilation path",
       %{test: test, tmp_dir: tmp_dir} = context do
    create_test_mix_file(context)
    write_fixture(context)

    # Reference output: the existing force-recompile path.
    capture_io(fn ->
      in_project(test, tmp_dir, fn _module -> run([]) end)
    end)

    reference_default = read_file(context, "priv/gettext/default.pot")
    reference_domain = read_file(context, "priv/gettext/my_domain.pot")

    assert reference_default =~ ~s(msgid "hello")
    assert reference_default =~ ~s(msgid "one item")
    assert reference_default =~ ~s(msgid_plural "%{count} items")
    assert reference_default =~ ~s(msgctxt "a context")
    assert reference_default =~ "#. a comment for translators"
    assert reference_default =~ ~s(msgid "noop hello")
    assert reference_domain =~ ~s(msgid "domain hello")

    # On an up-to-date project, the attribute path must consider the
    # POT files written by the recompilation path unchanged.
    output =
      capture_io(fn ->
        in_project(test, tmp_dir, fn _module -> run_generate() end)
      end)

    refute output =~ "Extracted"
    assert read_file(context, "priv/gettext/default.pot") == reference_default
    assert read_file(context, "priv/gettext/my_domain.pot") == reference_domain

    # From scratch (no POT files), the attribute path must rebuild
    # byte-identical POT files without recompiling.
    File.rm_rf!(Path.join(tmp_dir, "priv/gettext"))

    output =
      capture_io(fn ->
        in_project(test, tmp_dir, fn _module -> run_generate() end)
      end)

    assert output =~ "Extracted priv/gettext/default.pot"
    assert output =~ "Extracted priv/gettext/my_domain.pot"

    # Not only equal to the reference, but independently containing the
    # expected content (guards against a bug shared by both paths).
    rebuilt_default = read_file(context, "priv/gettext/default.pot")
    assert rebuilt_default =~ ~s(msgid "hello")
    assert rebuilt_default =~ ~s(msgid_plural "%{count} items")
    assert rebuilt_default =~ "#. a comment for translators"

    assert rebuilt_default == reference_default
    assert read_file(context, "priv/gettext/my_domain.pot") == reference_domain
  end

  test "persists messages injected by macros into the consuming module",
       %{test: test, tmp_dir: tmp_dir} = context do
    create_test_mix_file(context)

    write_file(context, "lib/my_app.ex", """
    defmodule MyApp.Gettext do
      use Gettext.Backend, otp_app: #{inspect(test)}
    end

    defmodule MyApp.Labels do
      defmacro def_label(name, msgid) do
        quote do
          def unquote(name)(), do: gettext(unquote(msgid))
        end
      end
    end
    """)

    # This module does not contain the literal string "gettext\(" for its
    # message: the call is injected by the macro at expansion time.
    write_file(context, "lib/consumer.ex", """
    defmodule MyApp.Consumer do
      use Gettext, backend: MyApp.Gettext
      require MyApp.Labels

      MyApp.Labels.def_label(:active, "macro generated label")
    end
    """)

    capture_io(fn ->
      in_project(test, tmp_dir, fn _module -> run_generate() end)
    end)

    pot = read_file(context, "priv/gettext/default.pot")
    assert pot =~ ~s(msgid "macro generated label")
    assert pot =~ ~r{#: lib/consumer\.ex:\d+}
  end

  test "extracts messages from the _with_backend macros",
       %{test: test, tmp_dir: tmp_dir} = context do
    create_test_mix_file(context)

    write_file(context, "lib/my_app.ex", """
    defmodule MyApp.Gettext do
      use Gettext.Backend, otp_app: #{inspect(test)}
    end

    defmodule MyApp.WithBackend do
      require Gettext.Macros

      def singular(), do: Gettext.Macros.gettext_with_backend(MyApp.Gettext, "wb hello")

      def plural(n) do
        Gettext.Macros.ngettext_with_backend(MyApp.Gettext, "wb one", "wb many", n)
      end

      def noop(), do: Gettext.Macros.dgettext_noop_with_backend(MyApp.Gettext, "wb_domain", "wb noop")
    end
    """)

    capture_io(fn ->
      in_project(test, tmp_dir, fn _module -> run_generate() end)
    end)

    default_pot = read_file(context, "priv/gettext/default.pot")
    assert default_pot =~ ~s(msgid "wb hello")
    assert default_pot =~ ~s(msgid "wb one")
    assert default_pot =~ ~s(msgid_plural "wb many")
    assert read_file(context, "priv/gettext/wb_domain.pot") =~ ~s(msgid "wb noop")
  end

  test "merges references when two modules use the same msgid",
       %{test: test, tmp_dir: tmp_dir} = context do
    create_test_mix_file(context)

    write_file(context, "lib/my_app.ex", """
    defmodule MyApp.Gettext do
      use Gettext.Backend, otp_app: #{inspect(test)}
    end

    defmodule MyApp do
      use Gettext, backend: MyApp.Gettext
      def shared(), do: gettext("shared message")
    end
    """)

    write_file(context, "lib/other.ex", """
    defmodule MyApp.Other do
      use Gettext, backend: MyApp.Gettext
      def shared(), do: gettext("shared message")
    end
    """)

    capture_io(fn ->
      in_project(test, tmp_dir, fn _module -> run_generate() end)
    end)

    pot = read_file(context, "priv/gettext/default.pot")

    # One message, references from both BEAM files merged.
    assert length(String.split(pot, ~s(msgid "shared message"))) == 2
    assert pot =~ ~r{#: lib/my_app\.ex:\d+}
    assert pot =~ ~r{#: lib/other\.ex:\d+}
  end

  test "--merge updates PO files",
       %{test: test, tmp_dir: tmp_dir} = context do
    create_test_mix_file(context)
    write_fixture(context)

    write_file(context, "priv/gettext/it/LC_MESSAGES/default.po", "")

    capture_io(fn ->
      in_project(test, tmp_dir, fn _module -> run_generate(["--merge"]) end)
    end)

    po = read_file(context, "priv/gettext/it/LC_MESSAGES/default.po")
    assert po =~ ~s(msgid "hello")
    assert po =~ ~s(msgid "one item")
  end

  test "respects a custom :priv option on the backend",
       %{test: test, tmp_dir: tmp_dir} = context do
    create_test_mix_file(context)

    write_file(context, "lib/my_app.ex", """
    defmodule MyApp.Gettext do
      use Gettext.Backend, otp_app: #{inspect(test)}, priv: "priv/custom_gettext"
    end

    defmodule MyApp do
      use Gettext, backend: MyApp.Gettext
      def custom(), do: gettext("custom priv hello")
    end
    """)

    capture_io(fn ->
      in_project(test, tmp_dir, fn _module -> run_generate() end)
    end)

    assert read_file(context, "priv/custom_gettext/default.pot") =~
             ~s(msgid "custom priv hello")

    refute File.exists?(Path.join(tmp_dir, "priv/gettext/default.pot"))
  end

  test "--check-up-to-date passes when fresh and fails after a source change",
       %{test: test, tmp_dir: tmp_dir} = context do
    create_test_mix_file(context)
    write_fixture(context)

    capture_io(fn ->
      in_project(test, tmp_dir, fn _module ->
        run_generate()
      end)

      in_project(test, tmp_dir, fn _module ->
        run_generate(["--check-up-to-date"])
      end)
    end)

    # Change a message: the incremental compile inside the task must pick up
    # the changed file, refresh its attributes, and detect the stale POT.
    write_fixture_with_changed_msgid(context)

    expected_error =
      ~r{failed due to --check-up-to-date.*priv/gettext/default\.pot}s

    capture_io(fn ->
      assert_raise Mix.Error, expected_error, fn ->
        in_project(test, tmp_dir, fn _module ->
          run_generate(["--check-up-to-date"])
        end)
      end
    end)
  end

  test "--check-up-to-date sees source changes when compile already ran in the same VM",
       %{test: test, tmp_dir: tmp_dir} = context do
    create_test_mix_file(context)
    write_fixture(context)

    capture_io(fn ->
      in_project(test, tmp_dir, fn _module ->
        run_generate()
        assert read_file(context, "priv/gettext/default.pot") =~ ~s(msgid "hello")

        # "compile" (and the compilers it runs) already ran above and Mix
        # would skip them now. The task must reenable them, otherwise it reads
        # the BEAM files compiled before this change and the check passes
        # with outdated data.
        write_fixture_with_changed_msgid(context)

        assert_raise Mix.Error,
                     ~r{failed due to --check-up-to-date.*priv/gettext/default\.pot}s,
                     fn -> Mix.Tasks.Gettext.Generate.run(["--check-up-to-date"]) end
      end)
    end)
  end

  test "enabling automatic_extraction recompiles the modules compiled without it",
       %{test: test, tmp_dir: tmp_dir} = context do
    # Simulates adopting the task on an already compiled project: the toggle
    # is a compile-time configuration of every module that uses Gettext macros
    # (and of the backend), so flipping it in the config files recompiles them
    # all. Otherwise the BEAM files compiled before the change would carry no
    # messages and the task would silently drop them from the POT files.
    create_test_mix_file(context)
    write_fixture(context)
    write_config(context, automatic_extraction: false)

    capture_io(fn ->
      assert_raise Mix.Error, ~r/found no persisted Gettext messages/, fn ->
        in_project(test, tmp_dir, fn _module ->
          Mix.Task.run("loadconfig")
          run_generate()
        end)
      end
    end)

    assert Application.get_env(:gettext, MyApp.Gettext) == [automatic_extraction: false]

    # Flip the toggle in the config file only; no source file changes. Mix
    # detects the change through file mtimes with second granularity (the
    # config files must be newer than at the previous compilation, and before
    # Elixir 1.20 the .app file, which carries the compile-time values that
    # "mix compile" validates, is only regenerated when they are newer than
    # it), so make sure the rewrite lands in a later second than the compile.
    wait_for_next_second()
    write_config(context, automatic_extraction: true)

    capture_io(fn ->
      in_project(test, tmp_dir, fn _module ->
        Mix.Task.run("loadconfig")
        run_generate()
      end)
    end)

    default_pot = read_file(context, "priv/gettext/default.pot")
    assert default_pot =~ ~s(msgid "hello")
    assert default_pot =~ ~s(msgid "one item")
    assert read_file(context, "priv/gettext/my_domain.pot") =~ ~s(msgid "domain hello")
  end

  test "messages removed from the source are removed from the POT files",
       %{test: test, tmp_dir: tmp_dir} = context do
    create_test_mix_file(context)
    write_fixture(context)

    write_file(context, "lib/other.ex", """
    defmodule MyApp.Other do
      use Gettext, backend: MyApp.Gettext
      def hello(), do: gettext("hello from other")
    end
    """)

    capture_io(fn ->
      in_project(test, tmp_dir, fn _module -> run_generate() end)
    end)

    assert read_file(context, "priv/gettext/default.pot") =~ ~s(msgid "hello from other")

    # The compiler prunes the BEAM file of a deleted source file, so its
    # messages must disappear from the POT file on the next run.
    File.rm!(Path.join(tmp_dir, "lib/other.ex"))

    capture_io(fn ->
      in_project(test, tmp_dir, fn _module -> run_generate() end)
    end)

    default_pot = read_file(context, "priv/gettext/default.pot")
    refute default_pot =~ "hello from other"
    assert default_pot =~ ~s(msgid "hello")
  end

  test "extracts messages from deprecated \"use Gettext, otp_app:\" backends",
       %{test: test, tmp_dir: tmp_dir} = context do
    create_test_mix_file(context)

    write_file(context, "lib/my_app.ex", """
    defmodule MyApp.Gettext do
      use Gettext, otp_app: #{inspect(context.test)}
    end

    defmodule MyApp.Legacy do
      import MyApp.Gettext

      def singular(), do: gettext("legacy hello")
      def with_domain(), do: dgettext("my_domain", "legacy domain hello")
      def plural(n), do: ngettext("legacy one item", "legacy %{count} items", n)
      def noop(), do: gettext_noop("legacy noop hello")
    end
    """)

    # The deprecation warning for "use Gettext, otp_app:" is printed on stderr.
    capture_io(:stderr, fn ->
      capture_io(fn ->
        in_project(test, tmp_dir, fn _module -> run_generate() end)
      end)
    end)

    default_pot = read_file(context, "priv/gettext/default.pot")
    assert default_pot =~ ~s(msgid "legacy hello")
    assert default_pot =~ ~s(msgid "legacy one item")
    assert default_pot =~ ~s(msgid_plural "legacy %{count} items")
    assert default_pot =~ ~s(msgid "legacy noop hello")
    assert read_file(context, "priv/gettext/my_domain.pot") =~ ~s(msgid "legacy domain hello")
  end

  test "no attributes are persisted when automatic_extraction is disabled",
       %{test: test, tmp_dir: tmp_dir} = context do
    # With automatic_extraction off (the default), nothing must be persisted,
    # mirroring a :prod release compile.
    Application.delete_env(:gettext, MyApp.Gettext)
    create_test_mix_file(context)
    write_fixture(context)

    # The task compiles the project, finds no persisted attributes, and
    # refuses to silently produce empty output.
    capture_io(fn ->
      assert_raise Mix.Error, ~r/found no persisted Gettext messages/, fn ->
        in_project(test, tmp_dir, fn _module ->
          run_generate()
        end)
      end
    end)

    compile_dir = in_project(test, tmp_dir, fn _module -> Mix.Project.compile_path() end)
    beams = Path.wildcard(Path.join(compile_dir, "Elixir.MyApp*.beam"))
    assert beams != []

    for beam <- beams do
      {:ok, {_module, [attributes: attributes]}} =
        :beam_lib.chunks(String.to_charlist(beam), [:attributes])

      refute Keyword.has_key?(attributes, :__gettext_messages__)
      refute Keyword.has_key?(attributes, :__gettext_backend_module__)
    end
  end

  test "extracts each app of an umbrella project",
       %{test: test, tmp_dir: tmp_dir} = context do
    for backend <- [AppOne.Gettext, AppTwo.Gettext] do
      Application.put_env(:gettext, backend, automatic_extraction: true)
      on_exit(fn -> Application.delete_env(:gettext, backend) end)
    end

    write_file(context, "mix.exs", """
    defmodule UmbrellaFixture.MixProject do
      use Mix.Project

      def project() do
        [apps_path: "apps", version: "0.1.0"]
      end
    end
    """)

    for app <- ["app_one", "app_two"] do
      camelized = Macro.camelize(app)

      write_file(context, "apps/#{app}/mix.exs", """
      defmodule #{camelized}.MixProject do
        use Mix.Project

        def project() do
          [
            app: :#{app},
            version: "0.1.0"
          ]
        end

        def application() do
          [extra_applications: [:logger, :gettext]]
        end
      end
      """)

      write_file(context, "apps/#{app}/lib/#{app}.ex", """
      defmodule #{camelized}.Gettext do
        use Gettext.Backend, otp_app: :#{app}
      end

      defmodule #{camelized} do
        use Gettext, backend: #{camelized}.Gettext
        def hello(), do: gettext("hello from #{app}")
      end
      """)
    end

    capture_io(fn ->
      in_project(test, tmp_dir, fn _module -> run_generate() end)
    end)

    pot_one = read_file(context, "apps/app_one/priv/gettext/default.pot")
    pot_two = read_file(context, "apps/app_two/priv/gettext/default.pot")

    assert pot_one =~ ~s(msgid "hello from app_one")
    refute pot_one =~ "app_two"
    assert pot_two =~ ~s(msgid "hello from app_two")
    refute pot_two =~ "app_one"
  end

  test "extracts messages from all the apps of an umbrella project sharing a backend",
       %{test: test, tmp_dir: tmp_dir} = context do
    Application.put_env(:gettext, AppOne.Gettext, automatic_extraction: true)
    on_exit(fn -> Application.delete_env(:gettext, AppOne.Gettext) end)

    write_file(context, "mix.exs", """
    defmodule UmbrellaFixture.MixProject do
      use Mix.Project

      def project() do
        [apps_path: "apps", version: "0.1.0"]
      end
    end
    """)

    for {app, deps} <- [{"app_one", []}, {"app_two", [app_one: [in_umbrella: true]]}] do
      write_file(context, "apps/#{app}/mix.exs", """
      defmodule #{Macro.camelize(app)}.MixProject do
        use Mix.Project

        def project() do
          [
            app: :#{app},
            version: "0.1.0",
            deps: #{inspect(deps)}
          ]
        end

        def application() do
          [extra_applications: [:logger, :gettext]]
        end
      end
      """)
    end

    # The backend lives in app_one but app_two uses it too, as mix
    # gettext.extract supports: both messages must end up in app_one's POT.
    write_file(context, "apps/app_one/lib/app_one.ex", """
    defmodule AppOne.Gettext do
      use Gettext.Backend, otp_app: :app_one
    end

    defmodule AppOne do
      use Gettext, backend: AppOne.Gettext
      def hello(), do: gettext("hello from app_one")
    end
    """)

    write_file(context, "apps/app_two/lib/app_two.ex", """
    defmodule AppTwo do
      use Gettext, backend: AppOne.Gettext
      def hello(), do: gettext("hello from app_two")
    end
    """)

    capture_io(fn ->
      in_project(test, tmp_dir, fn _module ->
        # Through Mix.Task (as from the command line) rather than a direct
        # module call; rerun because the umbrella fixture of the previous test
        # shares the project module names, for which the task already ran.
        Mix.Task.rerun("gettext.generate", [])
      end)
    end)

    pot_one = read_file(context, "apps/app_one/priv/gettext/default.pot")
    assert pot_one =~ ~s(msgid "hello from app_one")
    assert pot_one =~ ~s(msgid "hello from app_two")
    refute File.exists?(Path.join(tmp_dir, "apps/app_two/priv/gettext"))

    # References are relative to each application, as mix gettext.extract
    # writes them (it compiles each application from its own directory).
    assert pot_one =~ ~r{^#: lib/app_one\.ex:\d+$}m
    assert pot_one =~ ~r{^#: lib/app_two\.ex:\d+$}m
    refute pot_one =~ "apps/"
  end

  test "reenables the compilers configured by the apps of an umbrella project",
       %{test: test, tmp_dir: tmp_dir} = context do
    Application.put_env(:gettext, AppOne.Gettext, automatic_extraction: true)
    on_exit(fn -> Application.delete_env(:gettext, AppOne.Gettext) end)

    # Mix caches the project of each app by app name, and the paths of the apps
    # of an umbrella by root project module, across Mix.Project.in_project
    # calls. The apps and the root project get names of their own: otherwise,
    # when another umbrella test ran first, its app_two mix.exs (without the
    # compiler below) would be reused and the compiler would never run.
    suffix = :erlang.phash2(test)
    app_one = :"app_one_#{suffix}"
    app_two = :"app_two_#{suffix}"

    write_file(context, "mix.exs", """
    defmodule UmbrellaFixture#{suffix}.MixProject do
      use Mix.Project

      def project() do
        [apps_path: "apps", version: "0.1.0"]
      end
    end
    """)

    write_file(context, "apps/#{app_one}/mix.exs", """
    defmodule AppOne.MixProject do
      use Mix.Project

      def project() do
        [app: #{inspect(app_one)}, version: "0.1.0"]
      end

      def application() do
        [extra_applications: [:logger, :gettext]]
      end
    end
    """)

    write_file(context, "apps/#{app_one}/lib/app_one.ex", """
    defmodule AppOne.Gettext do
      use Gettext.Backend, otp_app: #{inspect(app_one)}
    end

    defmodule AppOne do
      use Gettext, backend: AppOne.Gettext
      def hello(), do: gettext("hello from app_one")
    end
    """)

    # app_two configures a compiler of its own, which the umbrella root does
    # not know about. It counts how many times it runs.
    counter_key = {__MODULE__, test, :compiler_runs}

    write_file(context, "apps/#{app_two}/mix.exs", """
    defmodule Mix.Tasks.Compile.CountingFixture do
      use Mix.Task.Compiler
      @recursive true

      def run(_args) do
        key = #{inspect(counter_key)}
        :persistent_term.put(key, :persistent_term.get(key, 0) + 1)
        {:noop, []}
      end
    end

    defmodule AppTwo.MixProject do
      use Mix.Project

      def project() do
        [
          app: #{inspect(app_two)},
          version: "0.1.0",
          compilers: [:counting_fixture] ++ Mix.compilers()
        ]
      end
    end
    """)

    write_file(context, "apps/#{app_two}/lib/app_two.ex", """
    defmodule AppTwo do
      def hello(), do: :hello
    end
    """)

    capture_io(fn ->
      in_project(test, tmp_dir, fn _module ->
        Mix.Task.rerun("gettext.generate", [])
        assert :persistent_term.get(counter_key, 0) == 1

        # The compile tasks already ran in this VM: the task must reenable
        # app_two's compiler too, not only the ones configured at the root.
        Mix.Task.rerun("gettext.generate", [])
        assert :persistent_term.get(counter_key, 0) == 2
      end)
    end)

    assert read_file(context, "apps/#{app_one}/priv/gettext/default.pot") =~
             ~s(msgid "hello from app_one")
  end

  defp write_fixture_with_changed_msgid(context) do
    source =
      @fixture_source
      |> String.replace("%APP%", inspect(context.test))
      |> String.replace(~s{gettext("hello")}, ~s{gettext("hello changed")})

    write_file(context, "lib/my_app.ex", source)
  end

  defp write_config(context, automatic_extraction: enabled?) do
    write_file(context, "config/config.exs", """
    import Config
    config :gettext, MyApp.Gettext, automatic_extraction: #{enabled?}
    """)
  end

  defp wait_for_next_second(second \\ System.os_time(:second)) do
    if System.os_time(:second) > second do
      :ok
    else
      Process.sleep(50)
      wait_for_next_second(second)
    end
  end

  defp run(args) do
    Mix.Tasks.Gettext.Extract.run(args)
  end

  # Deliberately a plain call: the task itself must make sure the compile runs
  # even when "compile" already ran in this VM (see the "same VM" test above).
  defp run_generate(args \\ []) do
    Mix.Tasks.Gettext.Generate.run(args)
  end
end
