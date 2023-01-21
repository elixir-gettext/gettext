defmodule Mix.Tasks.Gettext.ExtractTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  @moduletag :tmp_dir

  setup_all do
    # To suppress the `redefining module MyApp` warnings for the test modules
    Code.compiler_options(ignore_module_conflict: true)
    :ok
  end

  test "extracting and extracting with --merge", %{test: test, tmp_dir: tmp_dir} = context do
    create_test_mix_file(context)

    write_file(context, "lib/my_app.ex", """
    defmodule MyApp.Gettext do
      use Gettext, otp_app: #{inspect(test)}
    end

    defmodule MyApp do
      require MyApp.Gettext
      def foo(), do: MyApp.Gettext.gettext("hello")
    end
    """)

    output =
      capture_io(fn ->
        Mix.Project.in_project(test, tmp_dir, fn _module -> run([]) end)
      end)

    assert output =~ "Extracted priv/gettext/default.pot"

    assert read_file(context, "priv/gettext/default.pot") =~ """
           #: lib/my_app.ex:7
           #, elixir-autogen, elixir-format
           msgid "hello"
           msgstr ""
           """

    # Test --merge too.

    write_file(context, "lib/other.ex", """
    defmodule MyApp.Other do
      require MyApp.Gettext
      def foo(), do: MyApp.Gettext.dgettext("my_domain", "other")
    end
    """)

    write_file(context, "priv/gettext/it/LC_MESSAGES/my_domain.po", "")

    capture_io(fn ->
      Mix.Project.in_project(test, tmp_dir, fn _module -> run(["--merge"]) end)
    end)

    assert read_file(context, "priv/gettext/it/LC_MESSAGES/my_domain.po") == """
           #: lib/other.ex:3
           #, elixir-autogen, elixir-format
           msgid "other"
           msgstr ""
           """
  end

  test "--check-up-to-date should fail if no POT files have been created",
       %{test: test, tmp_dir: tmp_dir} = context do
    create_test_mix_file(context)

    write_file(context, "lib/my_app.ex", """
    defmodule MyApp.Gettext do
    use Gettext, otp_app: #{inspect(test)}
    end

    defmodule MyApp do
    require MyApp.Gettext
    def foo(), do: MyApp.Gettext.gettext("hello")
    end
    """)

    write_file(context, "lib/other.ex", """
    defmodule MyApp.Other do
      require MyApp.Gettext
      def foo(), do: MyApp.Gettext.dgettext("my_domain", "other")
    end
    """)

    expected_message = """
    mix gettext.extract failed due to --check-up-to-date.
    The following POT files were not extracted or are out of date:

      * priv/gettext/default.pot
      * priv/gettext/my_domain.pot
    """

    capture_io(fn ->
      assert_raise Mix.Error, expected_message, fn ->
        Mix.Project.in_project(test, tmp_dir, fn _module ->
          run(["--check-up-to-date"])
        end)
      end
    end)
  end

  test "--check-up-to-date should pass if nothing changed",
       %{test: test, tmp_dir: tmp_dir} = context do
    create_test_mix_file(context, write_reference_comments: false)

    write_file(context, "lib/my_app.ex", """
    defmodule MyApp.Gettext do
      use Gettext, otp_app: #{inspect(test)}
    end

    defmodule MyApp do
      require MyApp.Gettext
      def foo(), do: MyApp.Gettext.gettext("hello")
    end
    """)

    capture_io(fn ->
      Mix.Project.in_project(test, tmp_dir, fn _module ->
        run([])
      end)

      Mix.Project.in_project(test, tmp_dir, fn _module ->
        run(["--check-up-to-date"])
      end)
    end)
  end

  test "--check-up-to-date should fail if POT files are outdated",
       %{test: test, tmp_dir: tmp_dir} = context do
    create_test_mix_file(context)

    write_file(context, "lib/my_app.ex", """
    defmodule MyApp.Gettext do
    use Gettext, otp_app: #{inspect(test)}
    end

    defmodule MyApp do
    require MyApp.Gettext
    def foo(), do: MyApp.Gettext.gettext("hello")
    end
    """)

    write_file(context, "lib/other.ex", """
    defmodule MyApp.Other do
      require MyApp.Gettext
      def foo(), do: MyApp.Gettext.dgettext("my_domain", "other")
    end
    """)

    capture_io(fn ->
      Mix.Project.in_project(test, tmp_dir, fn _module -> run([]) end)
    end)

    write_file(context, "lib/my_app.ex", """
    defmodule MyApp.Gettext do
    use Gettext, otp_app: #{inspect(test)}
    end

    defmodule MyApp do
    require MyApp.Gettext
    def foo(), do: MyApp.Gettext.gettext("new text")
    end
    """)

    expected_message = """
    mix gettext.extract failed due to --check-up-to-date.
    The following POT files were not extracted or are out of date:

      * priv/gettext/default.pot
    """

    capture_io(fn ->
      assert_raise Mix.Error, expected_message, fn ->
        Mix.Project.in_project(test, tmp_dir, fn _module ->
          run(["--check-up-to-date"])
        end)
      end
    end)
  end

  defp create_test_mix_file(context, gettext_config \\ []) do
    write_file(context, "mix.exs", """
    defmodule MyApp.MixProject do
      use Mix.Project

      def project() do
        [app: #{inspect(context.test)}, version: "0.1.0", gettext: #{inspect(gettext_config)}]
      end

      def application() do
        [extra_applications: [:logger, :gettext]]
      end
    end
    """)
  end

  defp write_file(context, path, contents) do
    path = Path.join(context.tmp_dir, path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, contents)
  end

  defp read_file(context, path) do
    context.tmp_dir |> Path.join(path) |> File.read!()
  end

  defp run(args) do
    Mix.Tasks.Gettext.Extract.run(args)
  end
end
