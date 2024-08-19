defmodule Mix.Tasks.Gettext.ExtractTest do
  use ExUnit.Case

  import ExUnit.CaptureIO
  import GettextTest.MixProjectHelpers

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
      use Gettext.Backend, otp_app: #{inspect(test)}
    end

    defmodule MyApp do
      use Gettext, backend: MyApp.Gettext
      def foo(), do: gettext("hello")
    end
    """)

    output =
      capture_io(fn ->
        in_project(test, tmp_dir, fn _module -> run([]) end)
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
      use Gettext, backend: MyApp.Gettext
      def foo(), do: dgettext("my_domain", "other")
    end
    """)

    write_file(context, "priv/gettext/it/LC_MESSAGES/my_domain.po", "")

    capture_io(fn ->
      in_project(test, tmp_dir, fn _module -> run(["--merge"]) end)
    end)

    assert read_file(context, "priv/gettext/it/LC_MESSAGES/my_domain.po") == """
           #: lib/other.ex:3
           #, elixir-autogen, elixir-format
           msgid "other"
           msgstr ""
           """

    capture_io(fn ->
      in_project(test, tmp_dir, fn _module -> run(["--merge"]) end)
    end) =~ "Wrote priv/gettext/it/LC_MESSAGES/my_domain.po"
  end

  test "--check-up-to-date should fail if no POT files have been created",
       %{test: test, tmp_dir: tmp_dir} = context do
    create_test_mix_file(context)

    write_file(context, "lib/my_app.ex", """
    defmodule MyApp.Gettext do
      use Gettext.Backend, otp_app: #{inspect(test)}
    end

    defmodule MyApp do
      use Gettext, backend: MyApp.Gettext
      def foo(), do: gettext("hello")
    end
    """)

    write_file(context, "lib/other.ex", """
    defmodule MyApp.Other do
      use Gettext, backend: MyApp.Gettext
      def foo(), do: dgettext("my_domain", "other")
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
        in_project(test, tmp_dir, fn _module ->
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
      use Gettext.Backend, otp_app: #{inspect(test)}
    end

    defmodule MyApp do
      use Gettext, backend: MyApp.Gettext
      def foo(), do: gettext("hello")
    end
    """)

    capture_io(fn ->
      in_project(test, tmp_dir, fn _module ->
        run([])
      end)

      in_project(test, tmp_dir, fn _module ->
        run(["--check-up-to-date"])
      end)
    end)
  end

  test "--check-up-to-date should fail if POT files are outdated",
       %{test: test, tmp_dir: tmp_dir} = context do
    create_test_mix_file(context)

    write_file(context, "lib/my_app.ex", """
    defmodule MyApp.Gettext do
      use Gettext.Backend, otp_app: #{inspect(test)}
    end

    defmodule MyApp do
      use Gettext, backend: MyApp.Gettext
      def foo(), do: gettext("hello")
    end
    """)

    write_file(context, "lib/other.ex", """
    defmodule MyApp.Other do
      use Gettext, backend: MyApp.Gettext
      def foo(), do: dgettext("my_domain", "other")
    end
    """)

    capture_io(fn ->
      in_project(test, tmp_dir, fn _module -> run([]) end)
    end)

    write_file(context, "lib/my_app.ex", """
    defmodule MyApp.Gettext do
      use Gettext.Backend, otp_app: #{inspect(test)}
    end

    defmodule MyApp do
      use Gettext, backend: MyApp.Gettext
      def foo(), do: gettext("hello world")
    end
    """)

    expected_message = """
    mix gettext.extract failed due to --check-up-to-date.
    The following POT files were not extracted or are out of date:

      * priv/gettext/default.pot
    """

    capture_io(fn ->
      assert_raise Mix.Error, expected_message, fn ->
        in_project(test, tmp_dir, fn _module ->
          run(["--check-up-to-date"])
        end)
      end
    end)
  end

  defp run(args) do
    Mix.Tasks.Gettext.Extract.run(args)
  end
end
