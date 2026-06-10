defmodule Mix.Tasks.Gettext.ExtractFromAttributesTest do
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
    MyApp.WithBackend
  ]

  setup_all do
    # To suppress the `redefining module MyApp` warnings for the test modules
    previous = Code.compiler_options()[:ignore_module_conflict]
    Code.compiler_options(ignore_module_conflict: true)
    on_exit(fn -> Code.compiler_options(ignore_module_conflict: previous) end)
    :ok
  end

  setup do
    # Mix task invocation state and loaded fixture modules are global to the
    # test VM; reset both so that each test compiles its own project and
    # resolves backends against its own modules.
    for task <- ~w(compile compile.all compile.elixir compile.app loadpaths) do
      Mix.Task.reenable(task)
    end

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
    create_test_mix_file(context, extraction_environments: [:test])
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
        in_project(test, tmp_dir, fn _module -> run(["--from-attributes"]) end)
      end)

    refute output =~ "Extracted"
    assert read_file(context, "priv/gettext/default.pot") == reference_default
    assert read_file(context, "priv/gettext/my_domain.pot") == reference_domain

    # From scratch (no POT files), the attribute path must rebuild
    # byte-identical POT files without recompiling.
    File.rm_rf!(Path.join(tmp_dir, "priv/gettext"))

    output =
      capture_io(fn ->
        in_project(test, tmp_dir, fn _module -> run(["--from-attributes"]) end)
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
    create_test_mix_file(context, extraction_environments: [:test])

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
      in_project(test, tmp_dir, fn _module -> run(["--from-attributes"]) end)
    end)

    pot = read_file(context, "priv/gettext/default.pot")
    assert pot =~ ~s(msgid "macro generated label")
    assert pot =~ ~r{#: lib/consumer\.ex:\d+}
  end

  test "extracts messages from the _with_backend macros",
       %{test: test, tmp_dir: tmp_dir} = context do
    create_test_mix_file(context, extraction_environments: [:test])

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
      in_project(test, tmp_dir, fn _module -> run(["--from-attributes"]) end)
    end)

    default_pot = read_file(context, "priv/gettext/default.pot")
    assert default_pot =~ ~s(msgid "wb hello")
    assert default_pot =~ ~s(msgid "wb one")
    assert default_pot =~ ~s(msgid_plural "wb many")
    assert read_file(context, "priv/gettext/wb_domain.pot") =~ ~s(msgid "wb noop")
  end

  test "merges references when two modules use the same msgid",
       %{test: test, tmp_dir: tmp_dir} = context do
    create_test_mix_file(context, extraction_environments: [:test])

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
      in_project(test, tmp_dir, fn _module -> run(["--from-attributes"]) end)
    end)

    pot = read_file(context, "priv/gettext/default.pot")

    # One message, references from both BEAM files merged.
    assert length(String.split(pot, ~s(msgid "shared message"))) == 2
    assert pot =~ ~r{#: lib/my_app\.ex:\d+}
    assert pot =~ ~r{#: lib/other\.ex:\d+}
  end

  test "--from-attributes combined with --merge updates PO files",
       %{test: test, tmp_dir: tmp_dir} = context do
    create_test_mix_file(context, extraction_environments: [:test])
    write_fixture(context)

    write_file(context, "priv/gettext/it/LC_MESSAGES/default.po", "")

    capture_io(fn ->
      in_project(test, tmp_dir, fn _module -> run(["--from-attributes", "--merge"]) end)
    end)

    po = read_file(context, "priv/gettext/it/LC_MESSAGES/default.po")
    assert po =~ ~s(msgid "hello")
    assert po =~ ~s(msgid "one item")
  end

  test "respects a custom :priv option on the backend",
       %{test: test, tmp_dir: tmp_dir} = context do
    create_test_mix_file(context, extraction_environments: [:test])

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
      in_project(test, tmp_dir, fn _module -> run(["--from-attributes"]) end)
    end)

    assert read_file(context, "priv/custom_gettext/default.pot") =~
             ~s(msgid "custom priv hello")

    refute File.exists?(Path.join(tmp_dir, "priv/gettext/default.pot"))
  end

  test "--check-up-to-date passes when fresh and fails after a source change",
       %{test: test, tmp_dir: tmp_dir} = context do
    create_test_mix_file(context, extraction_environments: [:test])
    write_fixture(context)

    capture_io(fn ->
      in_project(test, tmp_dir, fn _module ->
        run(["--from-attributes"])
      end)

      in_project(test, tmp_dir, fn _module ->
        run(["--from-attributes", "--check-up-to-date"])
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
          run(["--from-attributes", "--check-up-to-date"])
        end)
      end
    end)
  end

  test "no attributes are persisted outside extraction environments",
       %{test: test, tmp_dir: tmp_dir} = context do
    # Default :extraction_environments is [:dev]; tests run in :test, so
    # nothing must be persisted, mirroring a :prod release compile.
    create_test_mix_file(context)
    write_fixture(context)

    # The task compiles the project, finds no persisted attributes, and
    # refuses to silently produce empty output.
    capture_io(fn ->
      assert_raise Mix.Error, ~r/found no persisted Gettext messages/, fn ->
        in_project(test, tmp_dir, fn _module ->
          run(["--from-attributes"])
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
            version: "0.1.0",
            gettext: [extraction_environments: [:test]]
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
      in_project(test, tmp_dir, fn _module ->
        # Mix.Task.run (not a direct module call) so that @recursive true
        # recurses into each umbrella app.
        Mix.Task.run("gettext.extract", ["--from-attributes"])
      end)
    end)

    pot_one = read_file(context, "apps/app_one/priv/gettext/default.pot")
    pot_two = read_file(context, "apps/app_two/priv/gettext/default.pot")

    assert pot_one =~ ~s(msgid "hello from app_one")
    refute pot_one =~ "app_two"
    assert pot_two =~ ~s(msgid "hello from app_two")
    refute pot_two =~ "app_one"
  end

  defp write_fixture_with_changed_msgid(context) do
    source =
      @fixture_source
      |> String.replace("%APP%", inspect(context.test))
      |> String.replace(~s{gettext("hello")}, ~s{gettext("hello changed")})

    write_file(context, "lib/my_app.ex", source)
  end

  defp run(args) do
    Mix.Tasks.Gettext.Extract.run(args)
  end
end
