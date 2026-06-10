defmodule Mix.Tasks.Gettext.ExtractFromAttributesTest do
  use ExUnit.Case

  import ExUnit.CaptureIO
  import GettextTest.MixProjectHelpers

  @moduletag :tmp_dir

  setup_all do
    # To suppress the `redefining module MyApp` warnings for the test modules
    Code.compiler_options(ignore_module_conflict: true)
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
    for module <- [MyApp.Gettext, MyApp, MyApp.Labels, MyApp.Consumer] do
      :code.purge(module)
      :code.delete(module)
      :code.purge(module)
    end

    # Also drop previous test projects' ebin dirs from the code path
    # (in_project is called with prune_code_paths: false), so that the
    # unloaded fixture modules cannot be lazily re-loaded from a previous
    # test's _build.
    tmp_root = Path.join(File.cwd!(), "tmp")

    for path <- :code.get_path(),
        path_string = List.to_string(path),
        String.starts_with?(path_string, tmp_root) do
      :code.del_path(path)
    end

    # Drain extractor state left behind by other test files (their fixture
    # projects use the same MyApp.Gettext module name, so leftover messages
    # would be popped into this test's POT files).
    Agent.update(Gettext.ExtractorAgent, fn state ->
      %{state | messages: %{}, backends: []}
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
    assert read_file(context, "priv/gettext/default.pot") == reference_default
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
    assert pot =~ "#: lib/consumer.ex:5"
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

    capture_io(fn ->
      assert_raise Mix.Error, ~r/mix gettext\.extract failed due to --check-up-to-date/, fn ->
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

    beams = Path.wildcard(Path.join(tmp_dir, "_build/**/Elixir.MyApp*.beam"))
    assert beams != []

    for beam <- beams do
      {:ok, {_module, [attributes: attributes]}} =
        :beam_lib.chunks(String.to_charlist(beam), [:attributes])

      refute Keyword.has_key?(attributes, :__gettext_messages__)
      refute Keyword.has_key?(attributes, :__gettext_backend_module__)
    end
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
